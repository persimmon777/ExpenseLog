import Foundation

// MARK: - Аналитика (CLAUDE.md, 5.2)

/// Период аналитики.
enum AnalyticsPeriod: String, CaseIterable, Identifiable {
    case day, week, month

    var id: String { rawValue }

    var title: String {
        switch self {
        case .day: return "День"
        case .week: return "Неделя"
        case .month: return "Месяц"
        }
    }

    var component: Calendar.Component {
        switch self {
        case .day: return .day
        case .week: return .weekOfYear
        case .month: return .month
        }
    }

    /// «…чем вчера» / «…чем на прошлой неделе» / «…чем в прошлом месяце».
    var previousPhrase: String {
        switch self {
        case .day: return "вчера"
        case .week: return "на прошлой неделе"
        case .month: return "в прошлом месяце"
        }
    }
}

/// Траты одной категории за период. `categoryID == nil` — «Без категории».
struct CategoryTotal: Identifiable {
    let categoryID: UUID?
    let name: String
    let emoji: String
    /// `nil` — «Без категории» (рисуется серым).
    let colorHex: String?
    let total: Decimal
    let count: Int

    var id: String { categoryID?.uuidString ?? "uncategorized" }
}

/// Итоги периода: расходы отдельно, пополнения / переводы / долги — отдельно.
struct PeriodSummary {
    let period: AnalyticsPeriod
    let start: Date
    /// Конец (не включительно).
    let end: Date
    let total: Decimal
    let count: Int
    /// По убыванию суммы; «Без категории» — в общем списке, если есть.
    let categories: [CategoryTotal]
    let income: Decimal
    let transfers: Decimal
    let debtGiven: Decimal
    /// Изменение к прошлому такому же периоду, %. Для «Дня» не считается (владелец попросил).
    let changePercent: Double?
    /// План трат на период (из плана на неделю).
    let plan: Decimal?

    /// Доля категории в тратах, %.
    func percent(of value: Decimal) -> Double {
        guard total > 0 else { return 0 }
        return NSDecimalNumber(decimal: value / total * 100).doubleValue
    }

    /// «45,3%».
    func percentText(of value: Decimal) -> String {
        Fmt.percent(percent(of: value))
    }

    /// «На 12,4% меньше, чем на прошлой неделе».
    var comparisonText: String? {
        guard let change = changePercent else { return nil }
        if abs(change) < 0.05 { return "Столько же, сколько \(period.previousPhrase)" }
        let word = change < 0 ? "меньше" : "больше"
        return "На \(Fmt.percent(abs(change))) \(word), чем \(period.previousPhrase)"
    }

    /// Потрачено из плана — для полоски.
    var planStatus: LimitStatus? {
        guard let plan, plan > 0 else { return nil }
        return LimitStatus(spent: total, limit: plan)
    }

    /// «8 ноября» / «2–8 ноября» / «Ноябрь 2026».
    var title: String {
        switch period {
        case .day: return Fmt.dayMonth(start)
        case .week: return Fmt.dayRange(start, endExclusive: end)
        case .month: return Fmt.monthYear(start)
        }
    }

    /// Для отчёта и промпта: «8 ноября» / «неделю 2–8 ноября» / «ноябрь 2026».
    var reportPeriod: String {
        switch period {
        case .day: return Fmt.dayMonth(start)
        case .week: return "неделю \(Fmt.dayRange(start, endExclusive: end))"
        case .month: return Fmt.monthYear(start).lowercased()
        }
    }
}

extension AppData {

    func periodInterval(_ period: AnalyticsPeriod, containing date: Date) -> DateInterval {
        Fmt.calendar.dateInterval(of: period.component, for: date) ?? DateInterval(start: date, duration: 86_400)
    }

    /// Итоги периода, содержащего дату.
    func summary(_ period: AnalyticsPeriod, containing date: Date) -> PeriodSummary {
        let cal = Fmt.calendar
        let interval = periodInterval(period, containing: date)
        let start = interval.start, end = interval.end
        let inPeriod = transactions.filter { $0.date >= start && $0.date < end }
        let spending = inPeriod.filter { $0.countsAsExpense }
        let total = spending.reduce(Decimal(0)) { $0 + $1.amount }

        var byCategory: [UUID?: (Decimal, Int)] = [:]
        for tx in spending {
            let key: UUID? = category(tx.categoryID) == nil ? nil : tx.categoryID
            let current = byCategory[key] ?? (0, 0)
            byCategory[key] = (current.0 + tx.amount, current.1 + 1)
        }
        let categoryTotals: [CategoryTotal] = byCategory.map { entry -> CategoryTotal in
            let key = entry.key
            let value = entry.value
            if let cat = category(key) {
                return CategoryTotal(categoryID: cat.id, name: cat.name, emoji: cat.emoji, colorHex: cat.colorHex, total: value.0, count: value.1)
            }
            return CategoryTotal(categoryID: nil, name: "Без категории", emoji: "❓", colorHex: nil, total: value.0, count: value.1)
        }
        .sorted { (a: CategoryTotal, b: CategoryTotal) in a.total > b.total }

        func sum(_ kind: TxKind) -> Decimal {
            inPeriod.filter { $0.kind == kind }.reduce(Decimal(0)) { $0 + $1.amount }
        }

        var change: Double?
        if period != .day, let prevStart = cal.date(byAdding: period.component, value: -1, to: start) {
            let previous = expenseTotal(from: prevStart, to: start)
            if previous > 0 {
                change = NSDecimalNumber(decimal: (total - previous) / previous * 100).doubleValue
            }
        }

        return PeriodSummary(
            period: period, start: start, end: end,
            total: total, count: spending.count,
            categories: categoryTotals,
            income: sum(.income), transfers: sum(.transfer), debtGiven: sum(.debtGiven),
            changePercent: change,
            plan: plan(period, containing: date)
        )
    }

    /// Траты категории за полуинтервал. `categoryID == nil` — «Без категории» (в том числе удалённой).
    func expenses(from start: Date, to end: Date, categoryID: UUID?) -> [Transaction] {
        expenses(from: start, to: end)
            .filter { tx in
                if let categoryID { return tx.categoryID == categoryID }
                return category(tx.categoryID) == nil
            }
            .sorted { (a: Transaction, b: Transaction) in a.date > b.date }
    }

    /// Траты по дням (ключ — начало дня) — для точек в календаре.
    func dayTotals(from start: Date, to end: Date) -> [Date: Decimal] {
        let cal = Fmt.calendar
        var result: [Date: Decimal] = [:]
        for tx in expenses(from: start, to: end) {
            result[cal.startOfDay(for: tx.date), default: 0] += tx.amount
        }
        return result
    }

    // MARK: Текстовый отчёт

    /// Отчёт в формате CLAUDE.md, 5.2.
    func reportText(_ s: PeriodSummary) -> String {
        var lines = ["Spent: отчёт за \(s.reportPeriod)"]
        lines.append("Потрачено: \(Fmt.money(s.total)) (\(Fmt.plural(s.count, "покупка", "покупки", "покупок")))")
        if let plan = s.plan { lines.append("План: \(Fmt.money(plan))") }
        for item in s.categories where item.categoryID != nil {
            lines.append("\(item.name): \(Fmt.money(item.total)) (\(s.percentText(of: item.total)))")
        }
        if let none = s.categories.first(where: { $0.categoryID == nil }) {
            lines.append("Без категории: \(Fmt.money(none.total))")
        }
        if s.income > 0 { lines.append("Пополнения: +\(Fmt.money(s.income))") }
        if s.transfers > 0 { lines.append("Переводы: \(Fmt.money(s.transfers))") }
        if s.debtGiven > 0 { lines.append("Дал в долг: \(Fmt.money(s.debtGiven))") }
        if totalOwed > 0 { lines.append("Тебе должны: \(Fmt.money(totalOwed))") }
        return lines.joined(separator: "\n")
    }

    /// Текст для «Разобрать в DeepSeek»: просьба + отчёт.
    func deepSeekText(_ s: PeriodSummary) -> String {
        "Проанализируй мои траты за \(s.reportPeriod). Где я трачу нерационально и что можно сократить?\n\n" + reportText(s)
    }
}
