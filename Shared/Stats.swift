import Foundation

/// Статистика расходов. Везде, где считаются расходы, — только `kind.countsAsExpense`.
extension AppData {

    /// Траты за полуинтервал [start, end).
    func expenses(from start: Date, to end: Date) -> [Transaction] {
        transactions.filter { $0.kind.countsAsExpense && $0.date >= start && $0.date < end }
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
