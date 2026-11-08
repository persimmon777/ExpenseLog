import SwiftUI
import Charts

/// Гистограмма трат по категориям: горизонтальные полоски цвета категории, «Без категории» — серым.
struct CategoryChart: View {
    @Environment(\.theme) private var theme
    let summary: PeriodSummary

    var body: some View {
        let items = summary.categories
        Chart(items) { item in
            BarMark(
                x: .value("Сумма", NSDecimalNumber(decimal: item.total).doubleValue),
                y: .value("Категория", "\(item.emoji) \(item.name)")
            )
            .foregroundStyle(color(item))
            .cornerRadius(4)
            .annotation(position: .trailing, alignment: .leading) {
                Text(summary.percentText(of: item.total))
                    .font(.caption2)
                    .foregroundStyle(theme.inkSoft)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .frame(height: CGFloat(max(items.count, 1)) * 32 + 8)
    }

    private func color(_ item: CategoryTotal) -> Color {
        guard let hex = item.colorHex else { return theme.inkSoft }
        return Color(hex: hex)
    }
}
