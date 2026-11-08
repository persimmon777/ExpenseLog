import Foundation

/// Статистика расходов. Везде, где считаются расходы, — только `tx.countsAsExpense`.
extension AppData {

    /// Траты за полуинтервал [start, end).
    func expenses(from start: Date, to end: Date) -> [Transaction] {
        transactions.filter { $0.countsAsExpense && $0.date >= start && $0.date < end }
    }

    func expenseTotal(from start: Date, to end: Date) -> Decimal {
        expenses(from: start, to: end).reduce(Decimal(0)) { $0 + $1.amount }
    }

    /// Траты за период календаря (`.day`, `.weekOfYear`, `.month`), содержащий дату.
    func expenses(in component: Calendar.Component, containing date: Date = Date()) -> [Transaction] {
        guard let interval = Fmt.calendar.dateInterval(of: component, for: date) else { return [] }
        return expenses(from: interval.start, to: interval.end)
    }

    func expenseTotal(in component: Calendar.Component, containing date: Date = Date()) -> Decimal {
        expenses(in: component, containing: date).reduce(Decimal(0)) { $0 + $1.amount }
    }

    /// Траты по дням за последние `days` дней (последний — сегодня). Для графика.
    func dailyTotals(lastDays days: Int, now: Date = Date()) -> [Decimal] {
        let cal = Fmt.calendar
        let today = cal.startOfDay(for: now)
        return (0..<days).reversed().map { (offset: Int) -> Decimal in
            guard let start = cal.date(byAdding: .day, value: -offset, to: today),
                  let end = cal.date(byAdding: .day, value: 1, to: start) else { return 0 }
            return expenseTotal(from: start, to: end)
        }
    }

    /// Сегодня против всего вчерашнего дня, в процентах.
    func todayChangePercent(now: Date = Date()) -> Int? {
        let cal = Fmt.calendar
        let today = cal.startOfDay(for: now)
        guard let yesterday = cal.date(byAdding: .day, value: -1, to: today),
              let tomorrow = cal.date(byAdding: .day, value: 1, to: today) else { return nil }
        return AppData.percentChange(expenseTotal(from: today, to: tomorrow), expenseTotal(from: yesterday, to: today))
    }

    /// Этот месяц (с 1-го числа до сейчас) против того же отрезка прошлого месяца, в процентах.
    func monthChangePercent(now: Date = Date()) -> Int? {
        let cal = Fmt.calendar
        guard let monthStart = cal.dateInterval(of: .month, for: now)?.start,
              let prevStart = cal.date(byAdding: .month, value: -1, to: monthStart) else { return nil }
        let elapsed = now.timeIntervalSince(monthStart)
        let prevEnd = min(prevStart.addingTimeInterval(elapsed), monthStart)
        let current = expenseTotal(from: monthStart, to: now.addingTimeInterval(1))
        let previous = expenseTotal(from: prevStart, to: prevEnd)
        return AppData.percentChange(current, previous)
    }

    /// Изменение в процентах; `nil`, если сравнивать не с чем.
    static func percentChange(_ current: Decimal, _ previous: Decimal) -> Int? {
        guard previous > 0 else { return nil }
        let ratio = NSDecimalNumber(decimal: (current - previous) / previous * 100).doubleValue
        return Int(ratio.rounded())
    }

    /// Сумма трат за день (для заголовков истории).
    func expenseTotal(onDay day: Date) -> Decimal {
        let cal = Fmt.calendar
        let start = cal.startOfDay(for: day)
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else { return 0 }
        return expenseTotal(from: start, to: end)
    }

    /// Прогноз на конец месяца = траты с начала месяца / прошедшие дни (включая сегодня) × дней в месяце.
    func monthForecast(now: Date = Date()) -> Decimal {
        let cal = Fmt.calendar
        let spent = expenseTotal(in: .month, containing: now)
        let daysPassed = cal.component(.day, from: now)
        let daysInMonth = cal.range(of: .day, in: .month, for: now)?.count ?? 30
        guard daysPassed > 0 else { return spent }
        return spent / Decimal(daysPassed) * Decimal(daysInMonth)
    }
}
