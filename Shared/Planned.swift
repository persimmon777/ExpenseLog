import Foundation

// MARK: - Планируемое на месяц: траты и поступления
//
// Траты = некупленное из списка покупок + регулярные платежи этого месяца, которые ещё не найдены в SMS.
// Поступления = регулярные поступления этого месяца, которые ещё не пришли (не нашлось похожего пополнения)
//               + долги с датой возврата в этом месяце или раньше (просроченные), ещё не возвращённые.
// Неоплаченное/неполученное висит в списке до конца месяца (с пометкой, если дата прошла).

struct PlannedLine: Identifiable {
    enum Kind {
        case shopping, recurring, debt
    }

    let id: String
    let title: String
    let amount: Decimal
    let date: Date?
    let kind: Kind
    /// Дата уже прошла, а оплата/поступление не найдены.
    let isOverdue: Bool
    /// Категория (для конвертов бюджета на месяц).
    var categoryID: UUID? = nil
}

extension RecurringItem {
    /// Дата близко к одной из дат платежа (в пределах окна периода).
    func isNearOccurrence(_ date: Date) -> Bool {
        let cal = Fmt.calendar
        guard let from = cal.date(byAdding: .day, value: -matchWindowDays, to: date) else { return false }
        let occurrence = nextDate(onOrAfter: from)
        let days = abs(cal.dateComponents([.day], from: cal.startOfDay(for: occurrence), to: cal.startOfDay(for: date)).day ?? Int.max)
        return days <= matchWindowDays
    }
}

extension AppData {

    private func monthBounds(_ now: Date) -> (start: Date, end: Date)? {
        guard let month = Fmt.calendar.dateInterval(of: .month, for: now) else { return nil }
        return (month.start, month.end)
    }

    /// Регулярные платежи / поступления этого месяца, которые ещё не найдены в операциях.
    private func pendingRecurring(income: Bool, now: Date) -> [PlannedLine] {
        guard let month = monthBounds(now) else { return [] }
        let today = Fmt.calendar.startOfDay(for: now)
        var lines: [PlannedLine] = []
        for item in recurring where item.isActive && item.isIncome == income {
            for date in item.dates(from: month.start, to: month.end) where !item.isPaid(near: date) {
                lines.append(PlannedLine(
                    id: "recurring-\(item.id.uuidString)-\(Fmt.dayKey(date))",
                    title: item.title, amount: item.amount, date: date, kind: .recurring,
                    isOverdue: date < today, categoryID: item.categoryID
                ))
            }
        }
        return lines
    }

    /// Планируемые траты этого месяца.
    func plannedExpenses(now: Date = Date()) -> [PlannedLine] {
        let shopping = shoppingToBuy.map {
            PlannedLine(id: "shopping-\($0.id.uuidString)", title: $0.title, amount: $0.price ?? 0,
                        date: nil, kind: .shopping, isOverdue: false, categoryID: $0.categoryID)
        }
        let regular = pendingRecurring(income: false, now: now).sorted { ($0.date ?? now) < ($1.date ?? now) }
        return shopping + regular
    }

    /// Планируемые поступления этого месяца.
    func plannedIncomes(now: Date = Date()) -> [PlannedLine] {
        let today = Fmt.calendar.startOfDay(for: now)
        var lines = pendingRecurring(income: true, now: now)
        if let month = monthBounds(now) {
            for debt in activeDebts {
                guard let due = debt.dueDate, due < month.end else { continue }
                lines.append(PlannedLine(
                    id: "debt-\(debt.id.uuidString)", title: "Долг: \(debt.person)", amount: debt.amount,
                    date: due, kind: .debt, isOverdue: Fmt.calendar.startOfDay(for: due) < today
                ))
            }
        }
        return lines.sorted { ($0.date ?? now) < ($1.date ?? now) }
    }

    func plannedExpenseTotal(now: Date = Date()) -> Decimal {
        plannedExpenses(now: now).reduce(Decimal(0)) { $0 + $1.amount }
    }

    func plannedIncomeTotal(now: Date = Date()) -> Decimal {
        plannedIncomes(now: now).reduce(Decimal(0)) { $0 + $1.amount }
    }

    /// Сколько останется на карте: остаток − планируемые траты + планируемые поступления.
    func balanceAfterPlanned(now: Date = Date()) -> Decimal? {
        guard let balance = lastBalance else { return nil }
        return balance - plannedExpenseTotal(now: now) + plannedIncomeTotal(now: now)
    }
}
