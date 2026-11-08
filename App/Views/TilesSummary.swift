import SwiftUI

/// Главная в «Лаванде»: большая карточка «Сегодня» с графиком и сетка 2×2.
struct TilesSummary: View {
    @EnvironmentObject private var store: SpentStore
    @Environment(\.theme) private var theme
    let onBalanceTap: () -> Void
    let onPlannedTap: () -> Void

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        let data = store.data
        VStack(spacing: 12) {
            hero(data)
            LazyVGrid(columns: columns, spacing: 12) {
                tile(title: "Месяц", value: Fmt.money(data.expenseTotal(in: .month)), change: data.monthChangePercent())
                tile(title: "Прогноз\nна месяц", value: Fmt.money(data.monthForecast()))
                Button(action: onBalanceTap) {
                    tile(title: "На карте", value: data.lastBalance.map { Fmt.money($0) } ?? "указать", icon: "creditcard")
                }
                .buttonStyle(.plain)
                Button(action: onPlannedTap) {
                    tile(title: "Планируется\nкупить", value: Fmt.money(data.plannedTotal), icon: "cart")
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Части

    private func hero(_ data: AppData) -> some View {
        let values = data.dailyTotals(lastDays: 14).map { NSDecimalNumber(decimal: $0).doubleValue }
        let change = data.todayChangePercent()
        let shape = RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
        return HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Сегодня")
                    .font(.subheadline)
                    .foregroundStyle(theme.onAccent.opacity(0.9))
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(Fmt.money(data.expenseTotal(in: .day)))
                        .font(theme.amountFont(.title, weight: .bold))
                        .foregroundStyle(theme.onAccent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    if let change {
                        Text(Fmt.percentBadge(change))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.onAccent.opacity(0.85))
                    }
                }
            }
            Spacer(minLength: 0)
            ZStack {
                SparklineShape(values: values, closed: true)
                    .fill(LinearGradient(
                        colors: [theme.onAccent.opacity(0.35), theme.onAccent.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                SparklineShape(values: values)
                    .stroke(theme.onAccent, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
            .frame(width: 110, height: 48)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [theme.accent, theme.accent.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: shape
        )
    }

    private func tile(title: String, value: String, change: Int? = nil, icon: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                if let icon {
                    Image(systemName: icon)
                        .foregroundStyle(theme.accent)
                }
            }
            Spacer(minLength: 0)
            Text(value)
                .font(theme.amountFont(.title3, weight: .bold))
                .foregroundStyle(theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            if let change {
                Text(Fmt.percentBadge(change))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(change > 0 ? theme.danger : theme.positive)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
        .background(theme.paper, in: RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous))
        .contentShape(Rectangle())
    }
}
