import WidgetKit
import SwiftUI

/// Виджет «Баланс карты»: остаток из последней SMS (или указанный вручную).
struct BalanceWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: BalanceEntry

    private var theme: Theme { entry.theme }

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

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryInline:
            Text(entry.balance.map { "На карте: \(Fmt.money($0))" } ?? "На карте: —")
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text("На карте")
                    .font(.caption)
                Text(entry.balance.map { Fmt.money($0) } ?? "—")
                    .font(.headline)
                    .widgetAccentable()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(caption)
                    .font(.caption2)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        default:
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("На карте")
                        .font(.caption)
                        .foregroundStyle(theme.inkSoft)
                    Spacer()
                    Image(systemName: "creditcard")
                        .foregroundStyle(theme.accent)
                }
                Spacer(minLength: 0)
                if !entry.isShared {
                    Text("Нет доступа к данным")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.danger)
                    Text("Откройте Spent → Настройки → «Общая папка».")
                        .font(.caption2)
                        .foregroundStyle(theme.inkSoft)
                } else {
                    Text(entry.balance.map { Fmt.money($0) } ?? "—")
                        .font(theme.amountFont(.title2, weight: .bold))
                        .foregroundStyle(theme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text(caption)
                        .font(.caption2)
                        .foregroundStyle(theme.inkSoft)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    /// «из SMS, сегодня в 20:41» / «указан вручную, вчера в 09:10».
    private var caption: String {
        guard entry.balance != nil, let date = entry.balanceDate else { return "придёт с первой SMS банка" }
        return "\(entry.isManual ? "указан вручную" : "из SMS"), \(Fmt.dayTitle(date).lowercased()) в \(Fmt.time(date))"
    }
}
