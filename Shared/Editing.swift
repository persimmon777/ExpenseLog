import Foundation

// MARK: - Подписи операции

extension Transaction {
    /// Что показывать заголовком: для пополнения и снятия — человеческое название, место — мелко.
    var title: String {
        switch smsType {
        case .topUp?: return "Пополнение"
        case .cashWithdrawal?: return "Снятие наличных"
        default: return merchant
        }
    }

    /// Место показывается отдельной мелкой строкой.
    var placeSubtitle: String? {
        switch smsType {
        case .topUp?, .cashWithdrawal?: return merchant
        default: return nil
        }
    }
}

// MARK: - История по дням

struct DayGroup: Identifiable {
    let day: Date
    let items: [Transaction]
    var id: Date { day }
}

extension AppData {

    /// Все операции, сгруппированные по дням, новые сверху.
    func historyByDay() -> [DayGroup] {
        let cal = Fmt.calendar
        let grouped = Dictionary(grouping: transactions) { (tx: Transaction) in cal.startOfDay(for: tx.date) }
        let days = grouped.keys.sorted(by: >)
        return days.map { (day: Date) in
            let items = (grouped[day] ?? []).sorted { (a: Transaction, b: Transaction) in a.date > b.date }
            return DayGroup(day: day, items: items)
        }
    }

    // MARK: Изменения

    /// Ручная операция (траты наличными и т. п.).
    mutating func addManual(_ tx: Transaction) {
        var tx = tx
        tx.source = .manual
        if tx.kind != .expense { tx.categoryID = nil }
        transactions.append(tx)
        autoMatch(transactionAt: transactions.count - 1)
    }

    mutating func setNote(transactionID: UUID, note: String?) {
        guard let index = transactions.firstIndex(where: { $0.id == transactionID }) else { return }
        let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        transactions[index].note = trimmed.isEmpty ? nil : trimmed
    }

    mutating func addCategory(_ category: Category) {
        categories.append(category)
    }

    // MARK: Предпросмотр вставки

    enum PreviewStatus {
        case new, duplicate, previouslyDeleted
    }

    /// Чем станет SMS при добавлении — для предпросмотра «Вставить SMS».
    func previewStatus(_ sms: ParsedSMS) -> PreviewStatus {
        if deletedFingerprints.contains(sms.fingerprint) { return .previouslyDeleted }
        if transactions.contains(where: { $0.smsFingerprint == sms.fingerprint }) { return .duplicate }
        return .new
    }

    // MARK: Подсказка категории по MCC

    /// «Похоже на: Продукты» — по имени категории; нет такой категории — нет подсказки.
    func suggestedCategory(for tx: Transaction) -> Category? {
        guard tx.kind == .expense, let name = MCCHint.categoryName(forMCC: tx.mcc) else { return nil }
        return categories.first { $0.name.compare(name, options: .caseInsensitive) == .orderedSame }
    }
}

// MARK: - MCC → категория

enum MCCHint {
    private static let groups: [(String, [String])] = [
        ("Продукты", ["5411", "5412", "5422", "5441", "5451", "5462", "5499"]),
        ("Кафе", ["5811", "5812", "5813", "5814"]),
        ("Одежда", ["5611", "5621", "5631", "5641", "5651", "5661", "5691", "5699"]),
        ("Транспорт", ["4111", "4121", "4131", "4789", "5541", "5542"]),
        ("Развлечения", ["5815", "5816", "5817", "5818", "7832", "7841", "7922", "7991", "7994", "7996", "7997", "7999"]),
        ("Курсы", ["8211", "8220", "8241", "8244", "8249", "8299"]),
        ("Здоровье", ["5912", "8011", "8021", "8062", "8099"]),
        ("Связь", ["4812", "4814", "4899"]),
        ("Покупки", ["5300", "5310", "5311", "5331", "5399"])
    ]

    private static let table: [String: String] = {
        var t: [String: String] = [:]
        for (name, codes) in groups {
            for code in codes { t[code] = name }
        }
        return t
    }()

    static func categoryName(forMCC mcc: String?) -> String? {
        guard let mcc else { return nil }
        return table[mcc]
    }
}

// MARK: - Баланс карты

extension AppData {
    /// Установить остаток на карте вручную (если какие-то операции не попали в приложение).
    /// Следующая SMS с остатком (новее этого момента) снова обновит его автоматически.
    mutating func setBalance(_ value: Decimal, date: Date = Date()) {
        lastBalance = value
        lastBalanceDate = date
        balanceSetManually = true
    }

    // MARK: Учитывать в расчёте

    /// Галочка «Учитывать в расчёте трат». Выключено — трата остаётся в истории,
    /// но не попадает в итоги, категории, лимиты и виджет.
    mutating func setExcluded(transactionID: UUID, excluded: Bool) {
        guard let index = transactions.firstIndex(where: { $0.id == transactionID }) else { return }
        transactions[index].excludedFromTotals = excluded ? true : nil
    }
}

// MARK: - Магазины

/// Магазин в списке «Магазины»: все операции с одним ключом `Merchant.key`.
struct MerchantSummary: Identifiable {
    /// Ключ магазина (`Merchant.key`).
    let key: String
    /// Как магазин называется в SMS.
    let originalName: String
    /// Своё название, если задано.
    let customName: String?
    let count: Int
    /// Сумма трат (только те, что учитываются в расчёте).
    let total: Decimal
    let lastDate: Date
    let ruleCategoryID: UUID?
    /// Строка — это группа магазинов («Соседи»), а не один магазин.
    var groupID: UUID? = nil

    var id: String { key }
    var name: String { customName ?? originalName }
}

extension AppData {

    /// Своё название магазина или как в SMS.
    func merchantName(_ merchant: String) -> String {
        let key = Merchant.key(merchant)
        if !key.isEmpty, let custom = merchantNames[key] { return custom }
        if let group = group(forMerchant: merchant) { return group.name }
        return Merchant.shortName(merchant)
    }

    /// Заголовок операции с учётом своих названий магазинов.
    func displayTitle(for tx: Transaction) -> String {
        if tx.placeSubtitle != nil { return tx.title }
        return merchantName(tx.merchant)
    }

    /// Задать своё название магазина. Пустое — вернуть название из SMS.
    mutating func renameMerchant(_ merchant: String, to name: String?) {
        let key = Merchant.key(merchant)
        guard !key.isEmpty else { return }
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty || trimmed == Merchant.shortName(merchant) {
            merchantNames[key] = nil
        } else {
            merchantNames[key] = trimmed
        }
    }

    /// Правило «магазин → категория». `nil` — убрать правило.
    /// Новое правило сразу применяется к неотсортированным тратам в этом магазине.
    mutating func setRule(forMerchant merchant: String, categoryID: UUID?) {
        let key = Merchant.key(merchant)
        guard !key.isEmpty else { return }
        rules.removeAll { $0.pattern == key }
        guard let categoryID else { return }
        rules.append(MerchantRule(pattern: key, displayName: Merchant.shortName(merchant), categoryID: categoryID))
        for i in transactions.indices where transactions[i].isUncategorized && Merchant.key(transactions[i].merchant) == key {
            transactions[i].categoryID = categoryID
        }
    }

    /// Все магазины, где были траты, — последние сверху.
    func merchants() -> [MerchantSummary] {
        let purchases = transactions.filter { $0.placeSubtitle == nil && $0.kind != .income && $0.kind != .debtReturn }
        // Филиалы одной группы — одной строкой («group:<id>»).
        let grouped = Dictionary(grouping: purchases) { (tx: Transaction) -> String in
            if let group = group(forMerchant: tx.merchant) { return "group:\(group.id.uuidString)" }
            return Merchant.key(tx.merchant)
        }
        var result: [MerchantSummary] = []
        for (key, items) in grouped where !key.isEmpty {
            let sorted = items.sorted { (a: Transaction, b: Transaction) in a.date > b.date }
            guard let latest = sorted.first else { continue }
            if key.hasPrefix("group:"), let group = self.group(forMerchant: latest.merchant) {
                let total = items.filter { $0.countsAsExpense }.reduce(Decimal(0)) { $0 + $1.amount }
                result.append(MerchantSummary(
                    key: key, originalName: group.patternText, customName: group.name,
                    count: items.count, total: total, lastDate: latest.date,
                    ruleCategoryID: group.categoryID, groupID: group.id
                ))
                continue
            }
            let total = items.filter { $0.countsAsExpense }.reduce(Decimal(0)) { $0 + $1.amount }
            result.append(MerchantSummary(
                key: key,
                originalName: Merchant.shortName(latest.merchant),
                customName: merchantNames[key],
                count: items.count,
                total: total,
                lastDate: latest.date,
                ruleCategoryID: rules.first(where: { $0.pattern == key })?.categoryID
            ))
        }
        return result.sorted { (a: MerchantSummary, b: MerchantSummary) in a.lastDate > b.lastDate }
    }
}

// MARK: - Список покупок

extension AppData {

    /// Ещё не купленное — сверху новые.
    var shoppingToBuy: [ShoppingItem] {
        shoppingList.filter { !$0.isDone }.sorted { (a: ShoppingItem, b: ShoppingItem) in a.createdAt > b.createdAt }
    }

    var shoppingBought: [ShoppingItem] {
        shoppingList.filter { $0.isDone }.sorted { (a: ShoppingItem, b: ShoppingItem) in a.createdAt > b.createdAt }
    }

    /// Планируемые траты: сумма примерных цен того, что ещё не куплено.
    var plannedTotal: Decimal {
        shoppingList.filter { !$0.isDone }.reduce(Decimal(0)) { $0 + ($1.price ?? 0) }
    }

    mutating func addShoppingItem(title: String, price: Decimal?) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        shoppingList.append(ShoppingItem(title: trimmed, price: price))
    }

    mutating func updateShoppingItem(_ item: ShoppingItem) {
        guard let index = shoppingList.firstIndex(where: { $0.id == item.id }) else { return }
        shoppingList[index] = item
    }

    mutating func toggleShoppingItem(_ id: UUID) {
        guard let index = shoppingList.firstIndex(where: { $0.id == id }) else { return }
        shoppingList[index].isDone.toggle()
    }

    mutating func deleteShoppingItem(_ id: UUID) {
        shoppingList.removeAll { $0.id == id }
    }

    /// «Убрать купленное».
    mutating func clearBoughtShopping() {
        shoppingList.removeAll { $0.isDone }
    }
}

// MARK: - Текст итога добавления SMS

extension AppData.IngestResult {
    /// Короткий итог для «Быстрых команд»: «Добавлено: OZON 22,60 BYN», «Уже было», «Не операция — пропущено».
    var summary: String {
        if !added.isEmpty {
            let items = added.map { "\(Merchant.shortName($0.merchant)) \(Fmt.money($0.amount, currency: $0.currency))" }
            var text = "Добавлено: " + items.joined(separator: "; ")
            if !matched.isEmpty { text += ". Отмечено само: " + matched.joined(separator: "; ") }
            return text
        }
        if duplicates > 0 { return "Уже было — не добавлено" }
        if previouslyDeleted > 0 { return "Вы удаляли эту операцию — не добавлено" }
        return "Не операция по карте — пропущено"
    }
}

// MARK: - Импорт истории

extension AppData {
    /// Разложить неотсортированные траты по подсказке MCC (по желанию при импорте истории).
    /// Возвращает, сколько трат получили категорию.
    @discardableResult
    mutating func applyMCCSuggestions(to ids: Set<UUID>) -> Int {
        var count = 0
        for i in transactions.indices where ids.contains(transactions[i].id) && transactions[i].isUncategorized {
            if let category = suggestedCategory(for: transactions[i]) {
                transactions[i].categoryID = category.id
                count += 1
            }
        }
        return count
    }
}
