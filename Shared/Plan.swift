import Foundation

// MARK: - План трат: неделя → день и месяц

extension AppData {

    /// Понедельник недели, содержащей дату.
    func weekStart(_ date: Date) -> Date {
        Fmt.calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? Fmt.calendar.startOfDay(for: date)
    }

    /// План по умолчанию, действующий на неделе.
    func basePlan(forWeekStarting start: Date) -> Decimal? {
        weeklyPlanBase
            .filter { $0.from <= start }
            .max { (a: WeeklyPlanEntry, b: WeeklyPlanEntry) in a.from < b.from }?
            .amount
    }

    /// План по умолчанию сейчас (для экрана «План трат»).
    var currentBasePlan: Decimal? { basePlan(forWeekStarting: weekStart(Date())) }

    /// Задан ли план вручную для этой недели.
    func isWeekPlanOverridden(_ date: Date) -> Bool {
        weeklyPlanOverrides[Fmt.dayKey(weekStart(date))] != nil
    }

    /// План на неделю, содержащую дату: заданный вручную или по умолчанию.
    func weekPlan(containing date: Date) -> Decimal? {
        let start = weekStart(date)
        // Ручной план 0 — «без плана на эту неделю».
        if let custom = weeklyPlanOverrides[Fmt.dayKey(start)] { return custom > 0 ? custom : nil }
        return basePlan(forWeekStarting: start)
    }

    /// План на день = план недели / 7.
    func dayPlan(_ date: Date) -> Decimal? {
        guard let week = weekPlan(containing: date) else { return nil }
        return week / 7
    }

    // MARK: «Можно сегодня» с переносом

    /// Траты за календарный день.
    private func spent(onDay day: Date) -> Decimal {
        expenseTotal(onDay: day)
    }

    /// Что переходит с воскресенья на понедельник: только дневная часть плана воскресенья
    /// минус траты воскресенья (без накопленного за неделю). Перерасход воскресенья уменьшает понедельник.
    private func sundayCarry(intoWeekStarting monday: Date) -> Decimal {
        guard let sunday = Fmt.calendar.date(byAdding: .day, value: -1, to: monday),
              let base = dayPlan(sunday) else { return 0 }
        return base - spent(onDay: sunday)
    }

    /// Сколько всего можно потратить в этот день: дневная часть плана + остаток прошлых дней недели.
    /// Неистраченное прибавляется, перерасход вычитается (может стать отрицательным).
    /// Неделя начинается заново с понедельника; на понедельник переходит только итог воскресенья.
    func dayAllowance(_ date: Date) -> Decimal? {
        let cal = Fmt.calendar
        let day = cal.startOfDay(for: date)
        guard dayPlan(day) != nil else { return nil }
        let monday = weekStart(day)
        var current = monday
        var allowance = (dayPlan(monday) ?? 0) + sundayCarry(intoWeekStarting: monday)
        while current < day {
            let leftover = allowance - spent(onDay: current)
            guard let next = cal.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
            allowance = (dayPlan(current) ?? 0) + leftover
        }
        return allowance
    }

    /// Сколько ещё можно потратить сегодня (отрицательное — перерасход).
    func canSpendToday(now: Date = Date()) -> Decimal? {
        guard let allowance = dayAllowance(now) else { return nil }
        return allowance - spent(onDay: now)
    }

    /// Перенесено на сегодня с прошлых дней: плюс — остаток, минус — перерасход.
    func carriedIntoToday(now: Date = Date()) -> Decimal {
        guard let allowance = dayAllowance(now), let base = dayPlan(now) else { return 0 }
        return allowance - base
    }

    /// План на месяц = сумма дневных планов всех дней месяца.
    func monthPlan(containing date: Date) -> Decimal? {
        let cal = Fmt.calendar
        guard let month = cal.dateInterval(of: .month, for: date) else { return nil }
        var total = Decimal(0)
        var hasPlan = false
        var day = month.start
        while day < month.end {
            if let plan = dayPlan(day) {
                total += plan
                hasPlan = true
            }
            guard let next = cal.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return hasPlan ? total : nil
    }

    /// План на период аналитики.
    func plan(_ period: AnalyticsPeriod, containing date: Date) -> Decimal? {
        switch period {
        case .day: return dayAllowance(date)
        case .week: return weekPlan(containing: date)
        case .month: return monthPlan(containing: date)
        }
    }

    /// «Потрачено из плана» за период — для полоски.
    func planStatus(_ period: AnalyticsPeriod, containing date: Date = Date()) -> LimitStatus? {
        // День может уйти в минус из-за перерасхода прошлых дней — его всё равно показываем.
        guard let plan = plan(period, containing: date), plan > 0 || period == .day else { return nil }
        return LimitStatus(spent: expenseTotal(in: period.component, containing: date), limit: plan)
    }

    // MARK: Изменения

    /// Изменить план по умолчанию: действует с текущей недели и дальше, прошедшие недели не меняются.
    mutating func setBasePlan(_ amount: Decimal?, now: Date = Date()) {
        let start = weekStart(now)
        weeklyPlanBase.removeAll { $0.from >= start }
        weeklyPlanBase.append(WeeklyPlanEntry(from: start, amount: amount))
    }

    /// План для конкретной недели. `nil` — вернуть план по умолчанию.
    mutating func setWeekPlan(_ amount: Decimal?, weekContaining date: Date) {
        weeklyPlanOverrides[Fmt.dayKey(weekStart(date))] = amount
    }
}

// MARK: - Динамика трат (линейный график)

enum TrendGranularity: String, CaseIterable, Identifiable {
    case day, week, month

    var id: String { rawValue }

    var title: String {
        switch self {
        case .day: return "Дни"
        case .week: return "Недели"
        case .month: return "Месяцы"
        }
    }

    var component: Calendar.Component {
        switch self {
        case .day: return .day
        case .week: return .weekOfYear
        case .month: return .month
        }
    }
}

struct TrendPoint: Identifiable {
    let date: Date
    let total: Decimal
    let plan: Decimal?
    var id: Date { date }
}

extension AppData {

    /// Дни: все дни месяца, содержащего дату. Недели: 12 недель до выбранной. Месяцы: 12 месяцев до выбранного.
    func trend(_ granularity: TrendGranularity, endingAt date: Date) -> [TrendPoint] {
        let cal = Fmt.calendar
        var starts: [Date] = []
        switch granularity {
        case .day:
            guard let month = cal.dateInterval(of: .month, for: date) else { return [] }
            var day = month.start
            while day < month.end {
                starts.append(day)
                guard let next = cal.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
            }
        case .week, .month:
            guard let last = cal.dateInterval(of: granularity.component, for: date)?.start else { return [] }
            for offset in (0..<12).reversed() {
                if let start = cal.date(byAdding: granularity.component, value: -offset, to: last) {
                    starts.append(start)
                }
            }
        }
        return starts.map { (start: Date) -> TrendPoint in
            let end = cal.date(byAdding: granularity.component, value: 1, to: start) ?? start
            let plan: Decimal?
            switch granularity {
            case .day: plan = dayPlan(start)
            case .week: plan = weekPlan(containing: start)
            case .month: plan = monthPlan(containing: start)
            }
            return TrendPoint(date: start, total: expenseTotal(from: start, to: end), plan: plan)
        }
    }
}
