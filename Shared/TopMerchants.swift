import Foundation

// MARK: - Топ магазинов (группа магазинов считается одним магазином)

struct MerchantTotal: Identifiable {
    /// «group:<id>» для группы, иначе `Merchant.key`.
    let key: String
    let name: String
    let count: Int
    let total: Decimal
    var id: String { key }
}

extension AppData {

    /// Ключ, по которому траты собираются в один магазин: группа или `Merchant.key`.
    func merchantGroupingKey(_ merchant: String) -> String {
        if let group = group(forMerchant: merchant) { return "group:\(group.id.uuidString)" }
        let key = Merchant.key(merchant)
        return key.isEmpty ? Merchant.shortName(merchant) : key
    }

    /// Магазины категории за период по убыванию суммы. `categoryID == nil` — «Без категории».
    func topMerchants(categoryID: UUID?, from start: Date, to end: Date) -> [MerchantTotal] {
        let items = expenses(from: start, to: end, categoryID: categoryID)
        let grouped = Dictionary(grouping: items) { (tx: Transaction) in merchantGroupingKey(tx.merchant) }
        return grouped.map { entry -> MerchantTotal in
            let txs = entry.value
            let name = txs.first.map { displayTitle(for: $0) } ?? entry.key
            return MerchantTotal(key: entry.key, name: name, count: txs.count,
                                 total: txs.reduce(Decimal(0)) { $0 + $1.amount })
        }
        .sorted { (a: MerchantTotal, b: MerchantTotal) in a.total > b.total }
    }

    /// Траты одного магазина (или группы) в категории за период.
    func expenses(from start: Date, to end: Date, categoryID: UUID?, merchantKey: String) -> [Transaction] {
        expenses(from: start, to: end, categoryID: categoryID)
            .filter { merchantGroupingKey($0.merchant) == merchantKey }
    }
}
