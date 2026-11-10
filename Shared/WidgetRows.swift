import Foundation

// MARK: - Строки виджета «Траты за сегодня»
//
// Владелец сам выбирает до 3 строк: что считать (свободные деньги или конверт) и за какой срок (сегодня / неделя).
// Пример: «Свободно сегодня», «Развлечения на неделе», «Еда сегодня». Настройки → «Виджет» (`WidgetSettingsView`).

/// Настройка одной строки. `source`: «free» — свободные деньги (в плане на неделю — весь план), иначе id категории-конверта.
struct WidgetRowConfig: Codable, Hashable, Identifiable {
    enum Period: String, Codable, CaseIterable, Identifiable {
        case day, week
        var id: String { rawValue }
        var title: String { self == .day ? "Сегодня" : "Неделя" }
    }

    static let free = "free"

    var id = UUID()
    var source: String = WidgetRowConfig.free
    var period: Period = .day

    /// Сохранённые строки (по умолчанию — одна: свободные деньги сегодня).
    static var saved: [WidgetRowConfig] {
        get {
            guard let data = AppGroup.defaults.data(forKey: SharedSettings.Key.widgetRows),
                  let rows = try? JSONDecoder().decode([WidgetRowConfig].self, from: data), !rows.isEmpty else {
                return [WidgetRowConfig()]
            }
            return rows
        }
        set {
            AppGroup.defaults.set(try? JSONEncoder().encode(Array(newValue.prefix(maxRows))), forKey: SharedSettings.Key.widgetRows)
        }
    }

    static let maxRows = 3
}

/// Готовая строка для виджета.
struct WidgetRowValue: Identifiable, Hashable {
    let id: UUID
    /// «Свободно сегодня» / «Еда на неделе».
    let title: String
    let emoji: String?
    /// Сколько ещё можно (отрицательное — перерасход).
    let canSpend: Decimal
    /// Для полоски: потрачено из доступного за срок.
    let spent: Decimal
    let limit: Decimal
    /// Свободные деньги на сегодня — то же, что обычный вид виджета.
    var isFreeDay = false

    var isOver: Bool { canSpend < 0 }
    var ratio: Double {
        guard limit > 0 else { return spent > 0 ? 1 : 0 }
        return NSDecimalNumber(decimal: spent / limit).doubleValue
    }
}

extension AppData {

    /// Значения строк виджета на сейчас. Строки с удалённым конвертом пропускаются; без плана — пусто.
    func widgetRows(_ configs: [WidgetRowConfig] = WidgetRowConfig.saved, now: Date = Date()) -> [WidgetRowValue] {
        let cal = Fmt.calendar
        let today = cal.startOfDay(for: now)
        let monday = weekStart(today)
        let weekFrom = isMonthlyBudget ? max(monday, monthStart(today)) : monday
        let weekBefore = expenses(from: weekFrom, to: today)

        if let snapshot = monthlySnapshot(now) {
            let envelopeIDs = Set(snapshot.envelopes.map(\.id))
            return configs.compactMap { config in
                let days = Decimal(snapshot.daysLeftInWeek)
                if config.source == WidgetRowConfig.free {
                    let day = max(snapshot.freeDayAllowance, 0)
                    let spentToday = snapshot.freeSpentTodayTotal
                    if config.period == .day {
                        return WidgetRowValue(id: config.id, title: "Свободно сегодня", emoji: nil,
                                              canSpend: snapshot.freeCanSpendToday, spent: spentToday, limit: day, isFreeDay: true)
                    }
                    let before = weekBefore
                        .filter { tx in tx.categoryID.map { !envelopeIDs.contains($0) } ?? true }
                        .reduce(Decimal(0)) { $0 + $1.amount }
                    return WidgetRowValue(id: config.id, title: "Свободно на неделе", emoji: nil,
                                          canSpend: snapshot.freeCanSpendThisWeek,
                                          spent: before + spentToday, limit: before + day * days)
                }
                guard let envelope = snapshot.envelopes.first(where: { $0.id.uuidString == config.source }) else { return nil }
                let name = envelope.category.name
                if config.period == .day {
                    return WidgetRowValue(id: config.id, title: "\(name) сегодня", emoji: envelope.category.emoji,
                                          canSpend: envelope.canSpendToday, spent: envelope.spentToday, limit: envelope.dayAllowance)
                }
                let before = weekBefore.filter { $0.categoryID == envelope.id }.reduce(Decimal(0)) { $0 + $1.amount }
                return WidgetRowValue(id: config.id, title: "\(name) на неделе", emoji: envelope.category.emoji,
                                      canSpend: snapshot.envelopeCanSpendThisWeek(envelope),
                                      spent: before + envelope.spentToday, limit: before + envelope.dayAllowance * days)
            }
        }

        // План на неделю: конвертов нет, строки — по общему плану.
        return configs.compactMap { config in
            guard config.source == WidgetRowConfig.free else { return nil }
            if config.period == .day {
                guard let allowance = dayAllowance(now) else { return nil }
                let spent = expenseTotal(onDay: now)
                return WidgetRowValue(id: config.id, title: "Можно сегодня", emoji: nil,
                                      canSpend: allowance - spent, spent: spent, limit: max(allowance, 0), isFreeDay: true)
            }
            guard let week = weekPlan(containing: now) else { return nil }
            let spent = expenseTotal(in: .weekOfYear, containing: now)
            return WidgetRowValue(id: config.id, title: "Можно на неделе", emoji: nil,
                                  canSpend: week - spent, spent: spent, limit: week)
        }
    }
}
