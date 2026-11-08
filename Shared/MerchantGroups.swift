import Foundation

// MARK: - Группы магазинов

extension MerchantGroup {
    /// Подходит ли место из SMS: ключ места содержит ключ группы целым словом или частью
    /// («SOSEDI» найдётся в «SOSEDI 4/3/4» и в «OOO SOSEDI»).
    func matches(_ merchant: String) -> Bool {
        let key = Merchant.key(merchant)
        guard !pattern.isEmpty, !key.isEmpty else { return false }
        return key == pattern || key.contains(pattern)
    }
}

extension AppData {

    /// Группа, к которой относится магазин (первая подходящая).
    func group(forMerchant merchant: String) -> MerchantGroup? {
        merchantGroups.first { $0.matches(merchant) }
    }

    /// Категория для новой траты: сначала правило «всегда относить», потом категория группы.
    func autoCategory(forMerchant merchant: String) -> UUID? {
        if let rule = rule(forMerchant: merchant) { return rule.categoryID }
        return group(forMerchant: merchant)?.categoryID
    }

    /// Магазины из истории, подходящие под текст группы — для предпросмотра.
    func merchantsMatching(_ text: String) -> [String] {
        let pattern = Merchant.key(text)
        guard !pattern.isEmpty else { return [] }
        let probe = MerchantGroup(name: "", pattern: pattern, patternText: text)
        var seen: Set<String> = []
        var result: [String] = []
        for tx in transactions.sorted(by: { $0.date > $1.date }) where tx.placeSubtitle == nil && probe.matches(tx.merchant) {
            let name = Merchant.shortName(tx.merchant)
            if seen.insert(name).inserted { result.append(name) }
        }
        return result
    }

    /// Сколько покупок и на какую сумму в группе.
    func groupStats(_ group: MerchantGroup) -> (count: Int, total: Decimal) {
        let items = transactions.filter { $0.placeSubtitle == nil && group.matches($0.merchant) }
        let total = items.filter { $0.countsAsExpense }.reduce(Decimal(0)) { $0 + $1.amount }
        return (items.count, total)
    }

    /// Сохранить группу. Новая категория сразу проставляется неразобранным покупкам группы.
    mutating func saveGroup(_ group: MerchantGroup) {
        if let index = merchantGroups.firstIndex(where: { $0.id == group.id }) {
            merchantGroups[index] = group
        } else {
            merchantGroups.append(group)
        }
        if let category = group.categoryID {
            for i in transactions.indices where transactions[i].isUncategorized && group.matches(transactions[i].merchant) {
                transactions[i].categoryID = category
            }
        }
    }

    mutating func deleteGroup(_ id: UUID) {
        merchantGroups.removeAll { $0.id == id }
    }
}
