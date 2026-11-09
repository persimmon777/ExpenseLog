import Foundation

// MARK: - Самоопределение платежа
// В пункте списка покупок или в регулярном платеже можно указать магазин и примерную сумму.
// Оплата в этом магазине на сумму ±20% сама отмечает пункт купленным / платёж оплаченным.

extension AppData {

    /// Допуск по сумме по умолчанию, %.
    static let defaultTolerancePercent = 20

    /// Сумма в пределах ±percent% от ожидаемой. Без ожидаемой суммы подходит любая.
    static func amountMatches(_ amount: Decimal, expected: Decimal?, percent: Int = AppData.defaultTolerancePercent) -> Bool {
        guard let expected, expected > 0 else { return true }
        let diff = amount > expected ? amount - expected : expected - amount
        return diff <= expected * Decimal(max(percent, 0)) / 100
    }

    /// Магазин операции совпадает с указанным: «OZON» найдётся в «OMBSHOP.OZON.BY».
    static func merchantMatches(_ merchant: String, key: String?) -> Bool {
        guard let key, !key.isEmpty else { return false }
        let txKey = Merchant.key(merchant)
        guard !txKey.isEmpty else { return false }
        return txKey == key || txKey.contains(key) || " \(txKey) ".contains(" \(key) ")
    }

    /// Проверить новую трату и отметить подходящие пункты. Возвращает подписи того, что отметилось.
    @discardableResult
    mutating func autoMatch(transactionAt index: Int) -> [String] {
        guard transactions.indices.contains(index) else { return [] }
        let tx = transactions[index]
        // Пополнение: ищем регулярное поступление с похожей суммой около его даты — «получено».
        if tx.kind == .income {
            if let i = recurring.firstIndex(where: { item in
                item.isActive && item.isIncome
                    && AppData.amountMatches(tx.amount, expected: item.amount, percent: item.tolerance)
                    && item.isNearOccurrence(tx.date)
                    && !item.isPaid(near: tx.date)
            }) {
                recurring[i].lastPaidDate = tx.date
                recurring[i].lastPaidTransactionID = tx.id
                return ["\(recurring[i].title) — поступление получено"]
            }
            return []
        }
        guard tx.kind == .expense else { return [] }
        var matched: [String] = []

        // Список покупок: первый некупленный пункт с этим магазином и подходящей суммой.
        if let i = shoppingList.firstIndex(where: { item in
            !item.isDone
                && AppData.merchantMatches(tx.merchant, key: item.merchantKey)
                && AppData.amountMatches(tx.amount, expected: item.price)
        }) {
            shoppingList[i].isDone = true
            shoppingList[i].matchedTransactionID = tx.id
            matched.append("\(shoppingList[i].title) — список покупок")
        }

        // Регулярные платежи: активный, магазин и сумма подходят, этот период ещё не оплачен.
        if let i = recurring.firstIndex(where: { item in
            item.isActive && !item.isIncome
                && AppData.merchantMatches(tx.merchant, key: item.merchantKey)
                && AppData.amountMatches(tx.amount, expected: item.amount, percent: item.tolerance)
                && item.isNearOccurrence(tx.date)
                && !item.isPaid(near: tx.date)
        }) {
            recurring[i].lastPaidDate = tx.date
            recurring[i].lastPaidTransactionID = tx.id
            if transactions[index].categoryID == nil, let category = recurring[i].categoryID {
                transactions[index].categoryID = category
            }
            matched.append("\(recurring[i].title) — регулярный платёж")
        }
        return matched
    }
}

extension RecurringItem {

    /// Допуск по сумме, %.
    var tolerance: Int { tolerancePercent ?? AppData.defaultTolerancePercent }

    /// Окно, в котором оплата считается за один и тот же период.
    var matchWindowDays: Int {
        switch period {
        case .weekly: return 3
        case .monthly: return 10
        case .yearly: return 30
        }
    }

    /// Уже найдена оплата рядом с датой (в пределах окна периода).
    func isPaid(near date: Date) -> Bool {
        guard let last = lastPaidDate else { return false }
        let days = abs(Fmt.calendar.dateComponents([.day], from: last, to: date).day ?? Int.max)
        return days <= matchWindowDays
    }

    /// Ближайший платёж уже оплачен (оплата пришла заранее или сегодня).
    func isUpcomingPaid(now: Date = Date()) -> Bool {
        isPaid(near: nextDate(onOrAfter: now))
    }
}
