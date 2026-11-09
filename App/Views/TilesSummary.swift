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
                tile(title: "Месяц", value: Fmt.money(data.expenseTotal(in: .month)),
                     subtitle: data.monthPlan(containing: Date()).map { "из \(Fmt.money($0))" },
                     change: data.monthPlan(containing: Date()) == nil ? data.monthChangePercent() : nil)
                tile(title: "Прогноз\nна месяц", value: Fmt.money(data.monthForecast()))
                Button(action: onBalanceTap) {
                    tile(title: "На карте", value: data.lastBalance.map { Fmt.money($0) } ?? "указать", icon: "creditcard")
                }
                .buttonStyle(.plain)
                Button(action: onPlannedTap) {
                    tile(title: "Планируется", value: "−" + Fmt.money(data.plannedExpenseTotal()),
                         subtitle: "+" + Fmt.money(data.plannedIncomeTotal()) + " поступит", icon: "cart")
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Части

    private func hero(_ data: AppData) -> some View {
        let values = data.dailyTotals(lastDays: 14).map { NSDecimalNumber(decimal: $0).doubleValue }
        let dayStatus = data.planStatus(.day)
        let weekStatus = data.planStatus(.week)
        let shape = RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Сегодня")
                        .font(.subheadline)
                        .foregroundStyle(theme.onAccent.opacity(0.9))
                    Text(Fmt.money(data.expenseTotal(in: .day)))
                        .font(theme.amountFont(.title, weight: .bold))
                        .foregroundStyle(theme.onAccent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    if let dayStatus {
                        Text(dayStatus.spent > dayStatus.limit
                             ? "Перерасход \(Fmt.money(dayStatus.spent - dayStatus.limit))"
                             : "Можно ещё \(Fmt.money(dayStatus.limit - dayStatus.spent))")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.onAccent.opacity(0.9))
                    }
                }
                Spacer(minLength: 0)
                if let mascot = data.mascotImageName() {
                    MascotBadge(imageName: mascot, size: 60)
                }
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
                .frame(width: data.mascotImageName() == nil ? 110 : 80, height: 48)
            }
            if let weekStatus {
                VStack(alignment: .leading, spacing: 4) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(theme.onAccent.opacity(0.25))
                            Capsule()
                                .fill(theme.onAccent)
                                .frame(width: geo.size.width * CGFloat(min(max(weekStatus.ratio, 0), 1)))
                        }
                    }
                    .frame(height: 6)
                    Text("Неделя: \(Fmt.money(weekStatus.spent)) из \(Fmt.money(weekStatus.limit))")
                        .font(.caption)
                        .foregroundStyle(theme.onAccent.opacity(0.9))
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [theme.accent, theme.accent.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: shape
        )
    }

    private func tile(title: String, value: String, subtitle: String? = nil, change: Int? = nil, icon: String? = nil) -> some View {
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
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(theme.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
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
