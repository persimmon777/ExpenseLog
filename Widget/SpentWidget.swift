import WidgetKit
import SwiftUI

// ВРЕМЕННЫЙ КАРКАС виджета «Траты за сегодня». Финальный дизайн — см. CLAUDE.md, «Виджет».

struct TodayEntry: TimelineEntry {
    let date: Date
    let total: Decimal
    let count: Int
}

struct TodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayEntry {
        TodayEntry(date: Date(), total: 23.4, count: 3)
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        let entry = makeEntry()
        // Обновиться в полночь, чтобы сумма сбросилась на ноль.
        let midnight = Calendar.current.startOfDay(for: Date()).addingTimeInterval(24 * 60 * 60 + 1)
        completion(Timeline(entries: [entry], policy: .after(midnight)))
    }

    private func makeEntry() -> TodayEntry {
        let data = DataFile.load()
        let today = data.transactions.filter {
            $0.kind.countsAsExpense && Calendar.current.isDateInToday($0.date)
        }
        let total = today.reduce(Decimal(0)) { $0 + $1.amount }
        return TodayEntry(date: Date(), total: total, count: today.count)
    }
}

struct TodayWidgetView: View {
    let entry: TodayEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Сегодня").font(.caption).foregroundStyle(.secondary)
            Text("\(NSDecimalNumber(decimal: entry.total).stringValue) BYN")
                .font(.system(.title2, design: .monospaced).weight(.bold))
                .minimumScaleFactor(0.5)
            Text("покупок: \(entry.count)").font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(for: .widget) { Color(.systemBackground) }
    }
}

struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SpentToday", provider: TodayProvider()) { entry in
            TodayWidgetView(entry: entry)
        }
        .configurationDisplayName("Траты за сегодня")
        .description("Сколько потрачено сегодня.")
        .supportedFamilies([.systemSmall])
    }
}

@main
struct SpentWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodayWidget()
    }
}
