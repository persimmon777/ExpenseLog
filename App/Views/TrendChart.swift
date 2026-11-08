import SwiftUI
import Charts

/// Линейный график трат по дням / неделям / месяцам; пунктир — план.
struct TrendChart: View {
    @Environment(\.theme) private var theme
    let points: [TrendPoint]
    let granularity: TrendGranularity

    var body: some View {
        let hasPlan = points.contains { $0.plan != nil }
        Chart {
            ForEach(points) { point in
                LineMark(
                    x: .value("Дата", point.date, unit: granularity.component),
                    y: .value("Траты", NSDecimalNumber(decimal: point.total).doubleValue),
                    series: .value("Ряд", "Траты")
                )
                .foregroundStyle(theme.accent)
                .interpolationMethod(.monotone)
                PointMark(
                    x: .value("Дата", point.date, unit: granularity.component),
                    y: .value("Траты", NSDecimalNumber(decimal: point.total).doubleValue)
                )
                .foregroundStyle(theme.accent)
                .symbolSize(granularity == .day ? 12 : 30)
            }
            if hasPlan {
                ForEach(points.filter { $0.plan != nil }) { point in
                    LineMark(
                        x: .value("Дата", point.date, unit: granularity.component),
                        y: .value("План", NSDecimalNumber(decimal: point.plan ?? 0).doubleValue),
                        series: .value("Ряд", "План")
                    )
                    .foregroundStyle(theme.inkSoft)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: granularity == .day ? 6 : 4)) { _ in
                AxisGridLine()
                AxisValueLabel(format: labelFormat)
            }
        }
        .environment(\.locale, Fmt.locale)
        .frame(height: 200)
    }

    private var labelFormat: Date.FormatStyle {
        switch granularity {
        case .day: return .dateTime.day()
        case .week: return .dateTime.day().month(.abbreviated)
        case .month: return .dateTime.month(.abbreviated)
        }
    }
}
