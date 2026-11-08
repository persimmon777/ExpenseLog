import Foundation

// MARK: - Тип операции

/// Тип операции. В расходы и аналитику по категориям идёт только `.expense`.
enum TxKind: String, Codable, CaseIterable, Identifiable {
    /// Трата (OPLATA или ручная).
    case expense
    /// Пополнение (POPOLNENIE KARTOCHKI или ручное).
    case income
    /// Перевод: снятие наличных (NALICHNYE), между своими картами, другу. Не расход.
    case transfer
    /// Деньги, данные в долг. Не расход — учитывается в разделе «Долги».
    case debtGiven
    /// Входящие деньги, закрывающие долг. Не доход.
    case debtReturn

    var id: String { rawValue }

    var title: String {
        switch self {
        case .expense: return "Трата"
        case .income: return "Пополнение"
        case .transfer: return "Перевод"
        case .debtGiven: return "Долг"
        case .debtReturn: return "Возврат долга"
        }
    }

    /// Учитывать ли в расходах (итоги, категории, лимиты, виджет).
    var countsAsExpense: Bool { self == .expense }

    /// Деньги уходят с карты (для знака суммы в списках).
    var isOutgoing: Bool {
        switch self {
        case .expense, .transfer, .debtGiven: return true
        case .income, .debtReturn: return false
        }
    }
}

/// Откуда пришла операция.
enum TxSource: String, Codable {
    case sms
    case manual
}

// MARK: - Операция

struct Transaction: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var amount: Decimal
    var currency: String = "BYN"
    /// Короткое место операции, например «OMBSHOP.OZON.BY» или «BR.527/209 BR.795/795 ATM».
    var merchant: String
    /// Полная строка места из SMS, например «OMBSHOP.OZON.BY>MINSKIY R-N>BY».
    var merchantRaw: String?
    var date: Date
    var kind: TxKind = .expense
    /// Категория — только для `.expense`.
    var categoryID: UUID?
    var mcc: String?
    var cardLast4: String?
    var balanceAfter: Decimal?
    var note: String?
    var source: TxSource = .manual
    /// Тип исходного SMS (OPLATA / POPOLNENIE / NALICHNYE), если операция из SMS.
    var smsType: SMSType?
    /// Отпечаток текста SMS (SHA-256 нормализованного текста) — защита от дублей.
    var smsFingerprint: String?
    /// Связанный долг (для `.debtGiven` и `.debtReturn`).
    var debtID: UUID?
    /// `true` — трата не учитывается в итогах, категориях и лимитах
    /// (например, заплатил за родителей). Остаётся в истории.
    var excludedFromTotals: Bool?

    /// Не учитывать в расчёте трат.
    var isExcluded: Bool { excludedFromTotals == true }

    /// Учитывать в расходах: тип «трата» и не исключена вручную.
    /// Везде, где считаются расходы, — этот фильтр.
    var countsAsExpense: Bool { kind.countsAsExpense && !isExcluded }

    var isUncategorized: Bool { kind == .expense && categoryID == nil && !isExcluded }
}

// MARK: - Категория

struct Category: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var emoji: String
    var colorHex: String
    /// Лимит на календарный месяц. `nil` — без лимита.
    var monthlyLimit: Decimal?

    static let palette: [String] = [
        "E4572E", "F3A712", "29BF12", "00A6A6", "2F80ED", "5B3CC4",
        "D63AF9", "FF5D8F", "8D6E63", "607D8B", "0F9D58", "FF8A00"
    ]

    /// «Дал в долг» намеренно не категория — для этого есть `Debt`.
    static func makeDefaults() -> [Category] {
        [
            Category(name: "Продукты", emoji: "🛒", colorHex: "29BF12"),
            Category(name: "Кафе", emoji: "☕️", colorHex: "F3A712"),
            Category(name: "Развлечения", emoji: "🎮", colorHex: "D63AF9"),
            Category(name: "Одежда", emoji: "👕", colorHex: "2F80ED"),
            Category(name: "Транспорт", emoji: "🚌", colorHex: "00A6A6"),
            Category(name: "Курсы", emoji: "📚", colorHex: "5B3CC4"),
            Category(name: "Здоровье", emoji: "💊", colorHex: "FF5D8F"),
            Category(name: "Связь", emoji: "📱", colorHex: "607D8B"),
            Category(name: "Покупки", emoji: "🛍️", colorHex: "FF8A00"),
            Category(name: "Другое", emoji: "📦", colorHex: "E4572E")
        ]
    }
}

// MARK: - Правило «магазин → категория»

struct MerchantRule: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    /// Нормализованный ключ магазина (см. `Merchant.key`).
    var pattern: String
    /// Как магазин выглядел при создании правила — для показа в списке.
    var displayName: String
    var categoryID: UUID
}

// MARK: - Долг

struct Debt: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    /// Кому дали.
    var person: String
    var amount: Decimal
    var currency: String = "BYN"
    var givenDate: Date
    /// Дата возврата. В этот день в 10:00 — локальное уведомление.
    var dueDate: Date?
    var isReturned: Bool = false
    var returnedDate: Date?
    var note: String?
    /// Операция выдачи долга (если долг сделан из операции по карте).
    var givenTransactionID: UUID?
    /// Входящая операция, которой долг вернули.
    var returnTransactionID: UUID?

    func isOverdue(now: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard !isReturned, let dueDate else { return false }
        return calendar.startOfDay(for: now) > calendar.startOfDay(for: dueDate)
    }
}

// MARK: - Список покупок

/// Пункт списка покупок: что купить и примерная цена.
struct ShoppingItem: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    /// Примерная цена. `nil` — не указана.
    var price: Decimal?
    var isDone: Bool = false
    var createdAt: Date = Date()
}

// MARK: - Регулярные платежи и поступления

/// Регулярный платёж (подписка, связь, аренда) или поступление (зарплата, стипендия).
struct RecurringItem: Identifiable, Codable, Hashable {
    enum Period: String, Codable, CaseIterable, Identifiable {
        case weekly, monthly, yearly
        var id: String { rawValue }
        var title: String {
            switch self {
            case .weekly: return "Каждую неделю"
            case .monthly: return "Каждый месяц"
            case .yearly: return "Каждый год"
            }
        }
    }

    var id: UUID = UUID()
    var title: String
    var amount: Decimal
    var currency: String = "BYN"
    /// `true` — поступление, `false` — платёж.
    var isIncome: Bool = false
    /// Категория платежа (для подсказки и иконки).
    var categoryID: UUID?
    var period: Period = .monthly
    /// Первая (опорная) дата: по ней берутся день недели / число / день года.
    var anchor: Date
    var isActive: Bool = true
    var note: String?
}

// MARK: - План трат на неделю

/// План по умолчанию, действующий с недели `from` (понедельник) и дальше.
/// Новая запись при изменении плана — так прошедшие недели не меняются.
struct WeeklyPlanEntry: Codable, Hashable {
    var from: Date
    /// `nil` — без плана с этой недели.
    var amount: Decimal?
}

// MARK: - Все данные приложения

struct AppData: Codable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int = AppData.currentSchemaVersion
    var transactions: [Transaction] = []
    var categories: [Category] = Category.makeDefaults()
    var rules: [MerchantRule] = []
    var debts: [Debt] = []
    /// Отпечатки удалённых SMS: такое SMS не вернётся при повторной вставке или срабатывании автоматизации.
    var deletedFingerprints: Set<String> = []
    /// Какие предупреждения о лимите уже отправлены: ключ «<categoryID>|yyyy-MM» → максимальный порог (80 или 100).
    var limitAlertsSent: [String: Int] = [:]
    var lastBalance: Decimal?
    var lastBalanceDate: Date?
    /// Остаток указан вручную (а не взят из SMS).
    var balanceSetManually = false
    /// Свои названия магазинов: ключ `Merchant.key` → название.
    var merchantNames: [String: String] = [:]
    /// Список покупок (планируемые траты).
    var shoppingList: [ShoppingItem] = []
    /// История плана на неделю по умолчанию.
    var weeklyPlanBase: [WeeklyPlanEntry] = []
    /// План, заданный вручную для конкретных недель: «yyyy-MM-dd» понедельника → сумма.
    var weeklyPlanOverrides: [String: Decimal] = [:]
    /// Регулярные платежи и поступления.
    var recurring: [RecurringItem] = []

    init() {}

    // Ручной декодер: новые поля добавляются через `decodeIfPresent`,
    // чтобы старый файл данных всегда открывался.
    enum CodingKeys: String, CodingKey {
        case schemaVersion, transactions, categories, rules, debts
        case deletedFingerprints, limitAlertsSent, lastBalance, lastBalanceDate
        case balanceSetManually, merchantNames, shoppingList
        case weeklyPlanBase, weeklyPlanOverrides, recurring
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 0
        transactions = try c.decodeIfPresent([Transaction].self, forKey: .transactions) ?? []
        categories = try c.decodeIfPresent([Category].self, forKey: .categories) ?? Category.makeDefaults()
        rules = try c.decodeIfPresent([MerchantRule].self, forKey: .rules) ?? []
        debts = try c.decodeIfPresent([Debt].self, forKey: .debts) ?? []
        deletedFingerprints = try c.decodeIfPresent(Set<String>.self, forKey: .deletedFingerprints) ?? []
        limitAlertsSent = try c.decodeIfPresent([String: Int].self, forKey: .limitAlertsSent) ?? [:]
        lastBalance = try c.decodeIfPresent(Decimal.self, forKey: .lastBalance)
        lastBalanceDate = try c.decodeIfPresent(Date.self, forKey: .lastBalanceDate)
        balanceSetManually = try c.decodeIfPresent(Bool.self, forKey: .balanceSetManually) ?? false
        merchantNames = try c.decodeIfPresent([String: String].self, forKey: .merchantNames) ?? [:]
        shoppingList = try c.decodeIfPresent([ShoppingItem].self, forKey: .shoppingList) ?? []
        weeklyPlanBase = try c.decodeIfPresent([WeeklyPlanEntry].self, forKey: .weeklyPlanBase) ?? []
        weeklyPlanOverrides = try c.decodeIfPresent([String: Decimal].self, forKey: .weeklyPlanOverrides) ?? [:]
        recurring = try c.decodeIfPresent([RecurringItem].self, forKey: .recurring) ?? []
        schemaVersion = AppData.currentSchemaVersion
    }

    // MARK: Поиск

    func category(_ id: UUID?) -> Category? {
        guard let id else { return nil }
        return categories.first { $0.id == id }
    }

    func transaction(_ id: UUID?) -> Transaction? {
        guard let id else { return nil }
        return transactions.first { $0.id == id }
    }

    var uncategorized: [Transaction] {
        transactions.filter { $0.isUncategorized }.sorted { $0.date > $1.date }
    }

    /// Сумма, которую сейчас должны пользователю.
    var totalOwed: Decimal {
        debts.filter { !$0.isReturned }.reduce(Decimal(0)) { $0 + $1.amount }
    }

    func rule(forMerchant merchant: String) -> MerchantRule? {
        let key = Merchant.key(merchant)
        guard !key.isEmpty else { return nil }
        return rules.first { rule in
            !rule.pattern.isEmpty && (key == rule.pattern || key.contains(rule.pattern))
        }
    }

    // MARK: Приём SMS

    struct IngestResult {
        var added: [Transaction] = []
        /// Такое SMS уже есть.
        var duplicates = 0
        /// Такое SMS было удалено пользователем — не возвращаем.
        var previouslyDeleted = 0
        /// Сколько фрагментов текста не удалось разобрать.
        var unrecognized = 0
    }

    /// Разбирает текст (одно или несколько SMS) и добавляет новые операции.
    @discardableResult
    mutating func ingest(smsText text: String) -> IngestResult {
        var result = IngestResult()
        let chunks = SMSParser.split(text)
        for chunk in chunks {
            guard let sms = SMSParser.parse(chunk) else {
                result.unrecognized += 1
                continue
            }
            if deletedFingerprints.contains(sms.fingerprint) {
                result.previouslyDeleted += 1
                continue
            }
            if transactions.contains(where: { $0.smsFingerprint == sms.fingerprint }) {
                result.duplicates += 1
                continue
            }
            var tx = Transaction(
                amount: sms.amount,
                currency: sms.currency,
                merchant: sms.place,
                merchantRaw: sms.placeRaw,
                date: sms.date ?? Date(),
                kind: sms.type.txKind,
                mcc: sms.mcc,
                cardLast4: sms.cardLast4,
                balanceAfter: sms.balance,
                source: .sms,
                smsType: sms.type,
                smsFingerprint: sms.fingerprint
            )
            if tx.kind == .expense, let matched = rule(forMerchant: tx.merchant) {
                tx.categoryID = matched.categoryID
            }
            transactions.append(tx)
            result.added.append(tx)
            if let balance = sms.balance, lastBalanceDate.map({ tx.date >= $0 }) ?? true {
                lastBalance = balance
                lastBalanceDate = tx.date
                balanceSetManually = false
            }
        }
        return result
    }

    // MARK: Категории и правила

    /// Назначает категорию. С `createRule` создаёт правило и применяет его
    /// ко всем неотсортированным тратам в этом магазине.
    mutating func categorize(transactionID: UUID, categoryID: UUID, createRule: Bool) {
        guard let index = transactions.firstIndex(where: { $0.id == transactionID }) else { return }
        transactions[index].kind = .expense
        transactions[index].categoryID = categoryID
        guard createRule else { return }
        let merchant = transactions[index].merchant
        let key = Merchant.key(merchant)
        guard !key.isEmpty else { return }
        rules.removeAll { $0.pattern == key }
        rules.append(MerchantRule(pattern: key, displayName: Merchant.shortName(merchant), categoryID: categoryID))
        for i in transactions.indices where transactions[i].isUncategorized && Merchant.key(transactions[i].merchant) == key {
            transactions[i].categoryID = categoryID
        }
    }

    mutating func setKind(transactionID: UUID, kind: TxKind) {
        guard let index = transactions.firstIndex(where: { $0.id == transactionID }) else { return }
        transactions[index].kind = kind
        if kind != .expense { transactions[index].categoryID = nil }
    }

    /// Удаляет категорию. Её траты становятся неотсортированными, правила удаляются.
    mutating func deleteCategory(_ id: UUID) {
        categories.removeAll { $0.id == id }
        rules.removeAll { $0.categoryID == id }
        for i in transactions.indices where transactions[i].categoryID == id {
            transactions[i].categoryID = nil
        }
    }

    // MARK: Удаление с отменой

    /// Удаляет операцию и запоминает отпечаток SMS. Возвращает удалённое — для кнопки «Отменить».
    @discardableResult
    mutating func deleteTransaction(_ id: UUID) -> Transaction? {
        guard let index = transactions.firstIndex(where: { $0.id == id }) else { return nil }
        let removed = transactions.remove(at: index)
        if let fp = removed.smsFingerprint { deletedFingerprints.insert(fp) }
        return removed
    }

    /// Отмена удаления (кнопка «Отменить» в течение 5 секунд).
    mutating func restoreTransaction(_ tx: Transaction) {
        if let fp = tx.smsFingerprint { deletedFingerprints.remove(fp) }
        guard !transactions.contains(where: { $0.id == tx.id }) else { return }
        transactions.append(tx)
    }

    // MARK: Долги

    /// Превращает операцию по карте в выданный долг.
    @discardableResult
    mutating func makeDebt(fromTransaction id: UUID, person: String, dueDate: Date?, note: String? = nil) -> Debt? {
        guard let index = transactions.firstIndex(where: { $0.id == id }) else { return nil }
        let tx = transactions[index]
        let debt = Debt(person: person, amount: tx.amount, currency: tx.currency, givenDate: tx.date,
                        dueDate: dueDate, note: note, givenTransactionID: tx.id)
        transactions[index].kind = .debtGiven
        transactions[index].categoryID = nil
        transactions[index].debtID = debt.id
        debts.append(debt)
        return debt
    }

    /// Отмечает долг возвращённым (или снимает отметку).
    /// Если указана входящая операция — она становится «Возвратом долга» и не считается доходом.
    mutating func setDebtReturned(_ debtID: UUID, returned: Bool, returnTransactionID: UUID? = nil, date: Date = Date()) {
        guard let index = debts.firstIndex(where: { $0.id == debtID }) else { return }
        // Снимаем старую привязку возврата.
        if let oldTx = debts[index].returnTransactionID,
           let txIndex = transactions.firstIndex(where: { $0.id == oldTx }) {
            transactions[txIndex].kind = .income
            transactions[txIndex].debtID = nil
        }
        debts[index].isReturned = returned
        debts[index].returnedDate = returned ? date : nil
        debts[index].returnTransactionID = returned ? returnTransactionID : nil
        if returned, let txID = returnTransactionID,
           let txIndex = transactions.firstIndex(where: { $0.id == txID }) {
            transactions[txIndex].kind = .debtReturn
            transactions[txIndex].categoryID = nil
            transactions[txIndex].debtID = debtID
        }
    }

    /// Удаляет долг. Связанная операция выдачи снова становится переводом.
    mutating func deleteDebt(_ debtID: UUID) {
        guard let debt = debts.first(where: { $0.id == debtID }) else { return }
        for i in transactions.indices where transactions[i].debtID == debtID {
            transactions[i].debtID = nil
            transactions[i].kind = transactions[i].id == debt.givenTransactionID ? .transfer : .income
        }
        debts.removeAll { $0.id == debtID }
    }
}

// MARK: - Названия магазинов

enum Merchant {
    /// «OMBSHOP.OZON.BY>MINSKIY R-N>BY» → «OMBSHOP.OZON.BY»
    static func shortName(_ raw: String) -> String {
        let first = raw.split(separator: ">", maxSplits: 1, omittingEmptySubsequences: true).first.map(String.init) ?? raw
        let trimmed = first.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? raw.trimmingCharacters(in: .whitespacesAndNewlines) : trimmed
    }

    /// Ключ для сравнения: верхний регистр, без знаков и чисто цифровых токенов.
    /// «EVROOPT 123» и «EVROOPT 456» дают один ключ «EVROOPT».
    static func key(_ name: String) -> String {
        let upper = shortName(name).uppercased()
        var cleaned = ""
        for scalar in upper.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                cleaned.unicodeScalars.append(scalar)
            } else {
                cleaned.append(" ")
            }
        }
        return cleaned
            .split(separator: " ")
            .map(String.init)
            .filter { token in !token.allSatisfy { $0.isNumber } }
            .joined(separator: " ")
    }
}

// MARK: - Тема

/// Темы оформления. «Игровая» — второй этап.
enum ThemeID: String, CaseIterable, Identifiable, Codable {
    case receipt
    case card
    case lavender

    var id: String { rawValue }

    var title: String {
        switch self {
        case .receipt: return "Чек"
        case .card: return "Карта"
        case .lavender: return "Лаванда"
        }
    }
}
