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
