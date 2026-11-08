import SwiftUI
import Charts

/// Линейный график трат по дням / неделям / месяцам; пунктир — план.
/// Нажатие (или проведение пальцем) по графику показывает сумму и период выбранной точки.
struct TrendChart: View {
    @Environment(\.theme) private var theme
    let points: [TrendPoint]
    let granularity: TrendGranularity

    @State private var selectedDate: Date?

    var body: some View {
        let hasPlan = points.contains { $0.plan != nil }
        let selected = nearestPoint(to: selectedDate)
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
                .symbolSize(selected?.date == point.date ? 90 : (granularity == .day ? 12 : 30))
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
            if let selected {
                RuleMark(x: .value("Дата", selected.date, unit: granularity.component))
                    .foregroundStyle(theme.inkSoft.opacity(0.35))
                    .annotation(position: .top, spacing: 4, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        callout(selected)
                    }
            }
        }
        .chartXSelection(value: $selectedDate)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: granularity == .day ? 6 : 4)) { _ in
                AxisGridLine()
                AxisValueLabel(format: labelFormat)
            }
        }
        .environment(\.locale, Fmt.locale)
        .frame(height: 220)
        .padding(.top, selected == nil ? 0 : 8)
        .onChange(of: granularity) { _, _ in selectedDate = nil }
    }

    // MARK: Подсказка

    private func callout(_ point: TrendPoint) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(periodTitle(point.date))
                .font(.caption2)
                .foregroundStyle(theme.inkSoft)
            Text(Fmt.money(point.total))
                .font(theme.amountFont(.subheadline, weight: .bold))
                .foregroundStyle(theme.ink)
            if let plan = point.plan {
                Text("план \(Fmt.money(plan))")
                    .font(.caption2)
                    .foregroundStyle(point.total > plan ? theme.danger : theme.inkSoft)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(theme.paper, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(theme.rule, lineWidth: 1))
    }

    /// «8 ноября» / «2–8 ноября» / «Ноябрь 2026».
    private func periodTitle(_ date: Date) -> String {
        switch granularity {
        case .day:
            return Fmt.dayMonth(date)
        case .week:
            let end = Fmt.calendar.date(byAdding: .day, value: 7, to: date) ?? date
            return Fmt.dayRange(date, endExclusive: end)
        case .month:
            return Fmt.monthYear(date)
        }
    }

    /// Ближайшая к нажатию точка.
    private func nearestPoint(to date: Date?) -> TrendPoint? {
        guard let date else { return nil }
        return points.min { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }
    }

    private var labelFormat: Date.FormatStyle {
        switch granularity {
        case .day: return .dateTime.day()
        case .week: return .dateTime.day().month(.abbreviated)
        case .month: return .dateTime.month(.abbreviated)
        }
    }
}
