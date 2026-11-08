import Foundation

// MARK: - Лимиты категорий (CLAUDE.md, раздел 6)

/// Состояние лимита категории за текущий месяц.
struct LimitStatus {
    enum Level {
        /// Меньше 80%.
        case ok
        /// 80–99%.
        case warning
        /// 100% и больше.
        case over
    }

    let spent: Decimal
    let limit: Decimal

    /// Доля потраченного (0…∞). `Double` — только для полоски.
    var ratio: Double {
        // Лимита нет совсем (день ушёл в минус из-за перерасхода) — сразу «исчерпан».
        guard limit > 0 else { return (spent > 0 || limit < 0) ? 1 : 0 }
        return NSDecimalNumber(decimal: spent / limit).doubleValue
    }

    var level: Level {
        if ratio >= 1 { return .over }
        if ratio >= 0.8 { return .warning }
        return .ok
    }
}

extension AppData {

    /// Траты категории за календарный месяц, содержащий дату.
    func categorySpent(_ categoryID: UUID, monthContaining date: Date = Date()) -> Decimal {
        expenses(in: .month, containing: date)
            .filter { $0.categoryID == categoryID }
            .reduce(Decimal(0)) { $0 + $1.amount }
    }

    func limitStatus(for category: Category, now: Date = Date()) -> LimitStatus? {
        guard let limit = category.monthlyLimit, limit > 0 else { return nil }
        return LimitStatus(spent: categorySpent(category.id, monthContaining: now), limit: limit)
    }

    /// Когда закончится лимит при таком темпе: сегодня + (лимит − потрачено) / средний расход в день.
    /// `nil`, если темп нулевой или лимит уже исчерпан.
    func limitRunOutDate(for category: Category, now: Date = Date()) -> Date? {
        guard let status = limitStatus(for: category, now: now), status.spent > 0, status.spent < status.limit else { return nil }
        let cal = Fmt.calendar
        let daysPassed = cal.component(.day, from: now)
        guard daysPassed > 0 else { return nil }
        let perDay = status.spent / Decimal(daysPassed)
        guard perDay > 0 else { return nil }
        let daysLeft = NSDecimalNumber(decimal: (status.limit - status.spent) / perDay).doubleValue
        return cal.date(byAdding: .day, value: Int(daysLeft.rounded(.down)), to: cal.startOfDay(for: now))
    }

    // MARK: Изменения

    mutating func updateCategory(_ category: Category) {
        guard let index = categories.firstIndex(where: { $0.id == category.id }) else { return }
        categories[index] = category
    }

    mutating func deleteRule(_ ruleID: UUID) {
        rules.removeAll { $0.id == ruleID }
    }
}

// MARK: - Долги (CLAUDE.md, 5.3)

extension AppData {

    /// Не вернули: сначала с ближайшей датой возврата, без даты — в конце.
    var activeDebts: [Debt] {
        debts.filter { !$0.isReturned }.sorted { (a: Debt, b: Debt) in
            let da = a.dueDate ?? .distantFuture
            let db = b.dueDate ?? .distantFuture
            return da == db ? a.givenDate > b.givenDate : da < db
        }
    }

    /// Вернули: последние сверху.
    var returnedDebts: [Debt] {
        debts.filter { $0.isReturned }.sorted { (a: Debt, b: Debt) in
            (a.returnedDate ?? a.givenDate) > (b.returnedDate ?? b.givenDate)
        }
    }

    func debt(_ id: UUID?) -> Debt? {
        guard let id else { return nil }
        return debts.first { $0.id == id }
    }

    /// Входящие операции, которыми мог вернуться долг (пополнения без связи с долгом), последние сверху.
    func debtReturnCandidates(limit: Int = 30) -> [Transaction] {
        Array(transactions
            .filter { $0.kind == .income && $0.debtID == nil }
            .sorted { (a: Transaction, b: Transaction) in a.date > b.date }
            .prefix(limit))
    }

    /// Долг, добавленный вручную (наличными и т. п.), без операции по карте.
    mutating func addDebt(_ debt: Debt) {
        debts.append(debt)
    }

    /// Изменить кому / сумму / даты / заметку. Сумму долга из операции по карте не меняем.
    mutating func updateDebt(_ debt: Debt) {
        guard let index = debts.firstIndex(where: { $0.id == debt.id }) else { return }
        var updated = debt
        if updated.givenTransactionID != nil {
            updated.amount = debts[index].amount
        }
        debts[index] = updated
    }
}

extension Debt {
    /// На сколько дней просрочен (0 — не просрочен).
    func overdueDays(now: Date = Date()) -> Int {
        guard isOverdue(now: now, calendar: Fmt.calendar), let dueDate else { return 0 }
        let cal = Fmt.calendar
        return cal.dateComponents([.day], from: cal.startOfDay(for: dueDate), to: cal.startOfDay(for: now)).day ?? 0
    }
}
