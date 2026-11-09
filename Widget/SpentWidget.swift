import WidgetKit
import SwiftUI

// Виджет «Траты за сегодня» (CLAUDE.md, раздел 9).
// Учитываются только траты (`countsAsExpense`). Обновляется в полночь и после каждого изменения данных.

/// Категория в топ-3 за день.
struct TopCategory: Identifiable {
    let name: String
    let emoji: String
    let colorHex: String?
    let total: Decimal
    var id: String { name }
}

struct TodayEntry: TimelineEntry {
    let date: Date
    let total: Decimal
    let count: Int
    let lastTitle: String?
    let lastAmount: Decimal?
    let top: [TopCategory]
    /// Сколько всего можно сегодня (дневной план + перенос с прошлых дней).
    let dayPlan: Decimal?
    /// Сколько ещё можно потратить сегодня (отрицательное — перерасход).
    let canSpend: Decimal?
    /// Перенесено с прошлых дней.
    let carried: Decimal
    /// Перерасход только за сегодня (виджет показывает только его).
    let overspentToday: Decimal
    /// Виджет видит общую папку с данными приложения.
    let isShared: Bool
    let theme: Theme
    /// Картинка персонажа (nil — выключен в настройках).
    var mascotImage: String? = nil

    static let sample = TodayEntry(
        date: Date(), total: 23.4, count: 3,
        lastTitle: "Кофейня", lastAmount: 4.5,
        top: [
            TopCategory(name: "Продукты", emoji: "🛒", colorHex: "29BF12", total: 12.3),
            TopCategory(name: "Кафе", emoji: "☕️", colorHex: "F3A712", total: 6.6),
            TopCategory(name: "Транспорт", emoji: "🚌", colorHex: "00A6A6", total: 4.5)
        ],
        dayPlan: 25, canSpend: 1.6, carried: 5, overspentToday: 0, isShared: true, theme: .receipt,
        mascotImage: "mascot-persimmon-3"
    )
}

struct TodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayEntry { .sample }

    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
        completion(context.isPreview ? .sample : makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        let entry = makeEntry()
        // Обновиться в полночь, чтобы сумма сбросилась на ноль.
        let tomorrow = Fmt.calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date().addingTimeInterval(86_400)
        let midnight = Fmt.calendar.startOfDay(for: tomorrow)
        completion(Timeline(entries: [entry], policy: .after(midnight)))
    }

    private func makeEntry() -> TodayEntry {
        let data = DataFile.load()
        let now = Date()
        let today = data.expenses(in: .day, containing: now)
        let total = today.reduce(Decimal(0)) { $0 + $1.amount }
        let last = today.max { (a: Transaction, b: Transaction) in a.date < b.date }
        let top = data.summary(.day, containing: now).categories.prefix(3).map {
            TopCategory(name: $0.name, emoji: $0.emoji, colorHex: $0.colorHex, total: $0.total)
        }
        return TodayEntry(
            date: now, total: total, count: today.count,
            lastTitle: last.map { data.displayTitle(for: $0) }, lastAmount: last?.amount,
            top: Array(top), dayPlan: data.dayAllowance(now), canSpend: data.canSpendToday(now: now),
            carried: data.carriedIntoToday(now: now), overspentToday: data.overspentToday(now: now),
            isShared: AppGroup.isShared, theme: Theme.current,
            mascotImage: data.mascotImageName(now: now)
        )
    }
}

struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SpentToday", provider: TodayProvider()) { entry in
            TodayWidgetView(entry: entry)
        }
        .configurationDisplayName("Траты за сегодня")
        .description("Сколько ещё можно потратить сегодня, с учётом остатка прошлых дней.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}

// MARK: - Баланс карты

struct BalanceEntry: TimelineEntry {
    let date: Date
    let balance: Decimal?
    let balanceDate: Date?
    let isManual: Bool
    /// Сколько ещё можно сегодня (nil — план не задан).
    let canSpend: Decimal?
    /// Перерасход только за сегодня.
    let overspentToday: Decimal
    let isShared: Bool
    let theme: Theme
    /// Картинка персонажа (nil — выключен в настройках).
    var mascotImage: String? = nil

    static let sample = BalanceEntry(date: Date(), balance: 512.4, balanceDate: Date(), isManual: false,
                                     canSpend: 8.4, overspentToday: 0, isShared: true, theme: .receipt,
                                     mascotImage: "mascot-persimmon-2")
}

struct BalanceProvider: TimelineProvider {
    func placeholder(in context: Context) -> BalanceEntry { .sample }

    func getSnapshot(in context: Context, completion: @escaping (BalanceEntry) -> Void) {
        completion(context.isPreview ? .sample : makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BalanceEntry>) -> Void) {
        // Обновляется после каждой операции (reloadAllTimelines) и в полночь — новый лимит дня.
        let tomorrow = Fmt.calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date().addingTimeInterval(86_400)
        completion(Timeline(entries: [makeEntry()], policy: .after(Fmt.calendar.startOfDay(for: tomorrow))))
    }

    private func makeEntry() -> BalanceEntry {
        let data = DataFile.load()
        let now = Date()
        return BalanceEntry(date: now, balance: data.lastBalance, balanceDate: data.lastBalanceDate,
                            isManual: data.balanceSetManually, canSpend: data.canSpendToday(now: now),
                            overspentToday: data.overspentToday(now: now), isShared: AppGroup.isShared, theme: Theme.current,
                            mascotImage: data.mascotImageName(now: now))
    }
}

struct BalanceWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SpentBalance", provider: BalanceProvider()) { entry in
            BalanceWidgetView(entry: entry)
        }
        .configurationDisplayName("Баланс и можно сегодня")
        .description("Остаток на карте и сколько ещё можно потратить сегодня.")
        .supportedFamilies([.systemSmall, .accessoryRectangular, .accessoryInline])
    }
}

@main
struct SpentWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodayWidget()
        BalanceWidget()
    }
}
