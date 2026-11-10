import Foundation

// MARK: - Бюджет на месяц с конвертами
//
// Режим «На месяц» (Настройки → «План трат»): на месяц задаётся сумма. Часть её раскладывается
// по «конвертам» — это лимиты категорий (`Category.monthlyLimit`), остальное — свободные деньги.
//
// Конверт: в день можно (конверт − потрачено в категории до сегодня − ещё не оплаченное запланированное
// этой категории) / дни до конца месяца, включая сегодня. Перерасход конверта берётся из свободных.
// Свободные: (бюджет − сумма конвертов − траты без конверта до сегодня − запланированное без конверта −
// перерасход конвертов) / дни до конца месяца — это и есть «Можно сегодня».
// Запланированное откладывается сразу, с 1-го числа; пришла SMS — сумма переходит в потраченное.
// Остатки в конце месяца сгорают, поступления бюджет не увеличивают.

enum BudgetMode: String, Codable, CaseIterable, Identifiable {
    case weekly, monthly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .weekly: return "На неделю"
        case .monthly: return "На месяц"
        }
    }
}

/// Конверт (категория с суммой на месяц) на конкретный день.
struct EnvelopeStatus: Identifiable {
    let category: Category
    /// Сколько заложено на месяц.
    let allocation: Decimal
    /// Потрачено в категории с 1-го числа до начала дня.
    let spentBefore: Decimal
    let spentToday: Decimal
    /// Ещё не оплаченное запланированное этой категории.
    let planned: Decimal
    /// Дней до конца месяца, включая этот.
    let daysLeft: Int

    var id: UUID { category.id }
    var spent: Decimal { spentBefore + spentToday }

    /// Сколько можно в день по конверту (на начало дня, не меньше нуля).
    var dayAllowance: Decimal { max(allocation - spentBefore - planned, 0) / Decimal(max(daysLeft, 1)) }
    /// Сколько ещё можно сегодня (отрицательное — перерасход за сегодня).
    var canSpendToday: Decimal { dayAllowance - spentToday }
    /// Сколько осталось в конверте с учётом запланированного.
    var remaining: Decimal { allocation - spent - planned }

    /// Перерасход конверта, который берётся из свободных денег: на начало дня и сейчас.
    var overflowBefore: Decimal { max(0, spentBefore + planned - allocation) }
    var overflowNow: Decimal { max(0, spent + planned - allocation) }

    /// Полоска: потрачено + запланировано из заложенного.
    var status: LimitStatus { LimitStatus(spent: spent + planned, limit: allocation) }
}

/// Состояние бюджета на месяц на конкретный день.
struct MonthlyBudgetSnapshot {
    let budget: Decimal
    let daysLeft: Int
    /// Дней до конца недели, включая этот (не дальше конца месяца).
    let daysLeftInWeek: Int
    let envelopes: [EnvelopeStatus]
    /// Траты без конверта: до начала дня и сегодня.
    let freeSpentBefore: Decimal
    let freeSpentToday: Decimal
    /// Запланированное без конверта.
    let freePlanned: Decimal

    var allocated: Decimal { envelopes.reduce(Decimal(0)) { $0 + $1.allocation } }
    /// Свободные деньги месяца (вне конвертов).
    var freeTotal: Decimal { budget - allocated }
    var plannedTotal: Decimal { freePlanned + envelopes.reduce(Decimal(0)) { $0 + $1.planned } }
    var spentBefore: Decimal { freeSpentBefore + envelopes.reduce(Decimal(0)) { $0 + $1.spentBefore } }

    private var overflowBefore: Decimal { envelopes.reduce(Decimal(0)) { $0 + $1.overflowBefore } }
    private var overflowToday: Decimal { envelopes.reduce(Decimal(0)) { $0 + ($1.overflowNow - $1.overflowBefore) } }

    /// Свободные деньги на этот день — «Можно сегодня».
    var freeDayAllowance: Decimal {
        (freeTotal - freeSpentBefore - freePlanned - overflowBefore) / Decimal(max(daysLeft, 1))
    }
    /// Потрачено сегодня из свободных: траты без конверта + перерасход конвертов за сегодня.
    var freeSpentTodayTotal: Decimal { freeSpentToday + overflowToday }
    /// Сколько ещё можно сегодня из свободных. Если свободных месяца не хватает на запланированное,
    /// дневная сумма считается нулём (это не перерасход за сегодня — см. `freeShortage`).
    var freeCanSpendToday: Decimal { max(freeDayAllowance, 0) - freeSpentTodayTotal }
    /// На сколько свободных денег месяца не хватает (из-за запланированного и прошлых трат). `nil` — хватает.
    var freeShortage: Decimal? {
        let left = freeTotal - freeSpentBefore - freePlanned - overflowBefore
        return left < 0 ? -left : nil
    }
    /// Сколько свободных осталось на месяц (с учётом запланированного).
    var freeRemaining: Decimal { freeTotal - freeSpentBefore - freePlanned - overflowBefore - freeSpentTodayTotal }

    /// Все деньги на день: свободные + конверты (для расчётной недели).
    var totalDayAllowance: Decimal {
        max(freeDayAllowance, 0) + envelopes.reduce(Decimal(0)) { $0 + $1.dayAllowance }
    }

    /// Сколько можно до конца недели: свободные на день × дни недели − потрачено сегодня из свободных.
    var freeCanSpendThisWeek: Decimal {
        max(freeDayAllowance, 0) * Decimal(daysLeftInWeek) - freeSpentTodayTotal
    }

    func envelopeCanSpendThisWeek(_ envelope: EnvelopeStatus) -> Decimal {
        envelope.dayAllowance * Decimal(daysLeftInWeek) - envelope.spentToday
    }
}

extension AppData {

    var isMonthlyBudget: Bool { budgetMode == .monthly }

    func monthStart(_ date: Date) -> Date {
        Fmt.calendar.dateInterval(of: .month, for: date)?.start ?? Fmt.calendar.startOfDay(for: date)
    }

    /// «yyyy-MM» месяца, содержащего дату.
    static func monthKey(_ date: Date) -> String {
        let c = Fmt.calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", c.year ?? 0, c.month ?? 0)
    }

    /// Бюджет по умолчанию, действующий в месяце.
    func baseBudget(forMonthStarting start: Date) -> Decimal? {
        monthlyBudgetBase
            .filter { $0.from <= start }
            .max { (a: WeeklyPlanEntry, b: WeeklyPlanEntry) in a.from < b.from }?
            .amount
    }

    var currentBaseBudget: Decimal? { baseBudget(forMonthStarting: monthStart(Date())) }

    func isMonthBudgetOverridden(_ date: Date) -> Bool {
        monthlyBudgetOverrides[AppData.monthKey(date)] != nil
    }

    /// Бюджет месяца: заданный вручную или по умолчанию (ручной 0 — без бюджета).
    func monthBudget(containing date: Date) -> Decimal? {
        if let custom = monthlyBudgetOverrides[AppData.monthKey(date)] { return custom > 0 ? custom : nil }
        return baseBudget(forMonthStarting: monthStart(date))
    }

    /// Категории с заложенной суммой — конверты.
    var envelopeCategories: [Category] {
        categories.filter { ($0.monthlyLimit ?? 0) > 0 }
    }

    /// Состояние бюджета на день. `nil` — не режим «На месяц» или бюджет не задан.
    /// Запланированное учитывается только для текущего месяца (для прошлых его уже не восстановить).
    func monthlySnapshot(_ date: Date = Date()) -> MonthlyBudgetSnapshot? {
        guard isMonthlyBudget, let budget = monthBudget(containing: date) else { return nil }
        let cal = Fmt.calendar
        let day = cal.startOfDay(for: date)
        guard let month = cal.dateInterval(of: .month, for: day),
              let tomorrow = cal.date(byAdding: .day, value: 1, to: day) else { return nil }
        let daysLeft = max(1, cal.dateComponents([.day], from: day, to: month.end).day ?? 1)
        let weekEnd = cal.dateInterval(of: .weekOfYear, for: day)?.end ?? tomorrow
        let daysLeftInWeek = max(1, cal.dateComponents([.day], from: day, to: min(weekEnd, month.end)).day ?? 1)

        // Оплаты запланированного (регулярные платежи, покупки из списка) уже были отложены из месяца —
        // они не «потрачено сегодня», а идут в траты месяца.
        let planPaid = planPaymentIDs
        let todayAll = expenses(from: day, to: tomorrow)
        let before = expenses(from: month.start, to: day) + todayAll.filter { planPaid.contains($0.id) }
        let today = todayAll.filter { !planPaid.contains($0.id) }
        let planned = cal.isDate(day, equalTo: Date(), toGranularity: .month) ? plannedExpenses(now: date) : []

        let envelopeIDs = Set(envelopeCategories.map(\.id))
        func sum(_ txs: [Transaction], _ id: UUID?) -> Decimal {
            txs.filter { tx in
                if let id { return tx.categoryID == id }
                return tx.categoryID.map { !envelopeIDs.contains($0) } ?? true
            }
            .reduce(Decimal(0)) { $0 + $1.amount }
        }
        func plannedSum(_ id: UUID?) -> Decimal {
            planned.filter { line in
                if let id { return line.categoryID == id }
                return line.categoryID.map { !envelopeIDs.contains($0) } ?? true
            }
            .reduce(Decimal(0)) { $0 + $1.amount }
        }

        let envelopes = envelopeCategories.map { category in
            EnvelopeStatus(
                category: category, allocation: category.monthlyLimit ?? 0,
                spentBefore: sum(before, category.id), spentToday: sum(today, category.id),
                planned: plannedSum(category.id), daysLeft: daysLeft
            )
        }
        return MonthlyBudgetSnapshot(
            budget: budget, daysLeft: daysLeft, daysLeftInWeek: daysLeftInWeek, envelopes: envelopes,
            freeSpentBefore: sum(before, nil), freeSpentToday: sum(today, nil), freePlanned: plannedSum(nil)
        )
    }

    /// Операции, которыми оплачено запланированное: регулярный платёж или пункт списка покупок.
    var planPaymentIDs: Set<UUID> {
        Set(recurring.compactMap { $0.isIncome ? nil : $0.lastPaidTransactionID }
            + shoppingList.compactMap { $0.isDone ? $0.matchedTransactionID : nil })
    }

    /// Сумма за период для главной. В бюджете на месяц за день не считаются оплаты запланированного
    /// (они заложены на месяц); неделя и месяц — все траты.
    func homeTotal(_ period: AnalyticsPeriod, now: Date = Date()) -> Decimal {
        guard isMonthlyBudget, period == .day else { return expenseTotal(in: period.component, containing: now) }
        let planPaid = planPaymentIDs
        return expenses(in: .day, containing: now)
            .filter { !planPaid.contains($0.id) }
            .reduce(Decimal(0)) { $0 + $1.amount }
    }

    /// Расчётная неделя в режиме «На месяц»: потрачено за неделю до сегодня + (свободные + конверты в день) × дни
    /// до конца недели. Только для недели, в которой сегодня.
    func expectedWeekInMonthlyMode(containing date: Date) -> Decimal? {
        let cal = Fmt.calendar
        guard cal.isDate(date, equalTo: Date(), toGranularity: .weekOfYear),
              let snapshot = monthlySnapshot(Date()) else { return nil }
        let today = cal.startOfDay(for: Date())
        let spentBefore = expenseTotal(from: weekStart(today), to: today)
        return spentBefore + snapshot.totalDayAllowance * Decimal(snapshot.daysLeftInWeek)
    }

    // MARK: Изменения

    mutating func setBudgetMode(_ mode: BudgetMode) {
        budgetMode = mode
    }

    /// Бюджет по умолчанию: действует с текущего месяца, прошедшие не меняются.
    mutating func setBaseBudget(_ amount: Decimal?, now: Date = Date()) {
        let start = monthStart(now)
        monthlyBudgetBase.removeAll { $0.from >= start }
        monthlyBudgetBase.append(WeeklyPlanEntry(from: start, amount: amount))
    }

    /// Свой бюджет для месяца. `nil` — вернуть бюджет по умолчанию, 0 — без бюджета.
    mutating func setMonthBudget(_ amount: Decimal?, monthContaining date: Date) {
        monthlyBudgetOverrides[AppData.monthKey(date)] = amount
    }

    /// Сумма конверта категории (она же лимит).
    mutating func setEnvelope(_ amount: Decimal?, categoryID: UUID) {
        guard let index = categories.firstIndex(where: { $0.id == categoryID }) else { return }
        categories[index].monthlyLimit = amount.flatMap { $0 > 0 ? $0 : nil }
    }

    /// Купили пункт списка наличными и т. п.: отметить купленным и добавить трату на его цену.
    mutating func buyShoppingItemWithExpense(_ id: UUID, now: Date = Date()) {
        guard let index = shoppingList.firstIndex(where: { $0.id == id }), let price = shoppingList[index].price else { return }
        let item = shoppingList[index]
        let tx = Transaction(amount: price, merchant: item.merchantName ?? item.title, date: now,
                             kind: .expense, categoryID: item.categoryID)
        transactions.append(tx)
        shoppingList[index].isDone = true
        shoppingList[index].matchedTransactionID = tx.id
    }
}
