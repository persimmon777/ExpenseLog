import WidgetKit
import SwiftUI

/// Вид виджета для каждого размера.
struct TodayWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TodayEntry

    private var theme: Theme { entry.theme }

    var body: some View {
        content
            .containerBackground(for: .widget) {
                if isAccessory {
                    Color.clear
                } else {
                    theme.paper
                }
            }
    }

    private var isAccessory: Bool {
        family == .accessoryRectangular || family == .accessoryInline || family == .accessoryCircular
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .systemMedium:
            HStack(spacing: 14) {
                todayColumn
                    .frame(maxWidth: .infinity, alignment: .leading)
                topColumn
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .accessoryRectangular:
            rectangular
        case .accessoryInline:
            if let canSpend = entry.canSpend {
                Text(entry.overspentToday > 0 ? "Перерасход: \(Fmt.money(entry.overspentToday))" : "Можно: \(Fmt.money(max(canSpend, 0)))")
            } else {
                Text("Coin: \(Fmt.money(entry.total))")
            }
        default:
            todayColumn
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    // MARK: Домашний экран

    private var todayColumn: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !entry.isShared {
                Text("Нет доступа к данным")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.danger)
                Text("Откройте Coin → Настройки → «Общая папка» и пришлите скриншот диагностики.")
                    .font(.caption2)
                    .foregroundStyle(theme.inkSoft)
                    .lineLimit(5)
                    .minimumScaleFactor(0.8)
            } else if let canSpend = entry.canSpend, let plan = entry.dayPlan {
                let over = entry.overspentToday > 0
                Text(over ? "Перерасход сегодня" : "Можно сегодня")
                    .font(.caption)
                    .foregroundStyle(over ? theme.danger : theme.inkSoft)
                Text(Fmt.money(over ? entry.overspentToday : max(canSpend, 0)))
                    .font(theme.amountFont(.title2, weight: .bold))
                    .foregroundStyle(over ? theme.danger : theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                bar(ratio: ratio(entry.total, max(plan, 0)), color: entry.overspentToday > 0 ? theme.danger : theme.accent)
                Text("потрачено \(Fmt.money(entry.total)) из \(Fmt.money(max(plan, 0)))")
                    .font(.caption2)
                    .foregroundStyle(theme.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if entry.carried > 0 {
                    Text("+\(Fmt.money(entry.carried)) с прошлых дней")
                        .font(.caption2)
                        .foregroundStyle(theme.positive)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            } else {
                Text("Сегодня")
                    .font(.caption)
                    .foregroundStyle(theme.inkSoft)
                Text(Fmt.money(entry.total))
                    .font(theme.amountFont(.title2, weight: .bold))
                    .foregroundStyle(theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text("Задайте план: Coin → Настройки → План трат — покажу, сколько можно")
                    .font(.caption2)
                    .foregroundStyle(theme.inkSoft)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            HStack(alignment: .bottom, spacing: 6) {
                if let title = entry.lastTitle, let amount = entry.lastAmount {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(title)
                            .font(.caption)
                            .foregroundStyle(theme.ink)
                            .lineLimit(1)
                        Text("−" + Fmt.money(amount))
                            .font(theme.amountFont(.caption2))
                            .foregroundStyle(theme.inkSoft)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                if entry.isShared, let mascot = entry.mascotImage {
                    MascotBadge(imageName: mascot, size: 36)
                }
            }
        }
    }

    private var topColumn: some View {
        let maxTotal = entry.top.map(\.total).max() ?? 0
        return VStack(alignment: .leading, spacing: 8) {
            Text("Больше всего")
                .font(.caption)
                .foregroundStyle(theme.inkSoft)
            if entry.top.isEmpty {
                Text("Покупок сегодня нет")
                    .font(.caption)
                    .foregroundStyle(theme.inkSoft)
            }
            ForEach(entry.top) { item in
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        Text("\(item.emoji) \(item.name)")
                            .font(.caption2)
                            .foregroundStyle(theme.ink)
                            .lineLimit(1)
                        Spacer(minLength: 2)
                        Text(Fmt.money(item.total))
                            .font(theme.amountFont(.caption2))
                            .foregroundStyle(theme.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    bar(ratio: ratio(item.total, maxTotal), color: item.colorHex.map { Color(hex: $0) } ?? theme.inkSoft)
                }
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: Экран блокировки

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let canSpend = entry.canSpend, let plan = entry.dayPlan {
                Text(entry.overspentToday > 0 ? "Перерасход: \(Fmt.money(entry.overspentToday))" : "Можно: \(Fmt.money(max(canSpend, 0)))")
                    .font(.headline)
                    .widgetAccentable()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("потрачено \(Fmt.money(entry.total))")
                    .font(.caption)
                    .lineLimit(1)
                ProgressView(value: min(ratio(entry.total, max(plan, 0)), 1))
                    .tint(.primary)
            } else {
                Text("Сегодня: \(Fmt.money(entry.total))")
                    .font(.headline)
                    .widgetAccentable()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(Fmt.plural(entry.count, "покупка", "покупки", "покупок"))
                    .font(.caption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Части

    private func bar(ratio: Double, color: Color) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(theme.rule)
                Capsule()
                    .fill(color)
                    .frame(width: geo.size.width * CGFloat(min(max(ratio, 0), 1)))
            }
        }
        .frame(height: 5)
    }

    private func ratio(_ value: Decimal, _ total: Decimal) -> Double {
        guard total > 0 else { return value > 0 || total < 0 ? 1 : 0 }
        return NSDecimalNumber(decimal: value / total).doubleValue
    }
}
