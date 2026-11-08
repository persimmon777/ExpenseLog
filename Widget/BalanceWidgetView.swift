import WidgetKit
import SwiftUI

/// Виджет «Баланс и можно сегодня»: остаток на карте и сколько ещё можно потратить за день.
struct BalanceWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: BalanceEntry

    private var theme: Theme { entry.theme }
    private var isOver: Bool { entry.overspentToday > 0 }

    var body: some View {
        content
            .containerBackground(for: .widget) {
                if family == .systemSmall {
                    theme.paper
                } else {
                    Color.clear
                }
            }
    }

    /// «12,40 BYN» / «−3,00 BYN» (перерасход) / «—» (нет плана).
    private var todayText: String {
        if isOver { return "−" + Fmt.money(entry.overspentToday) }
        guard let canSpend = entry.canSpend else { return "—" }
        return Fmt.money(max(canSpend, 0))
    }

    private var balanceText: String { entry.balance.map { Fmt.money($0) } ?? "—" }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryInline:
            Text("Карта \(balanceText) · можно \(todayText)")
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text("На карте: \(balanceText)")
                    .font(.headline)
                    .widgetAccentable()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(isOver ? "Перерасход сегодня: \(Fmt.money(entry.overspentToday))" : "Можно сегодня: \(todayText)")
                    .font(.subheadline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        default:
            if !entry.isShared {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Нет доступа к данным")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.danger)
                    Text("Откройте Coin → Настройки → «Общая папка».")
                        .font(.caption2)
                        .foregroundStyle(theme.inkSoft)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    block(title: "На карте", value: balanceText, color: theme.ink, icon: "creditcard")
                    Rectangle()
                        .fill(theme.rule)
                        .frame(height: 1)
                    block(title: isOver ? "Перерасход сегодня" : "Можно сегодня",
                          value: entry.canSpend == nil && !isOver ? "задайте план" : todayText,
                          color: isOver ? theme.danger : (entry.canSpend == nil ? theme.inkSoft : theme.accent),
                          icon: "calendar")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
        }
    }

    private func block(title: String, value: String, color: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(theme.inkSoft)
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(theme.inkSoft)
                    .lineLimit(1)
            }
            Text(value)
                .font(theme.amountFont(.title3, weight: .bold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
    }
}
