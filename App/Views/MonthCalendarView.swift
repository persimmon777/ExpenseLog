import SwiftUI

/// Свой календарь месяца: неделя с понедельника, слева номер недели, точки под днями с тратами.
/// Нажатие: день → «День», номер недели → «Неделя», название месяца → «Месяц».
struct MonthCalendarView: View {
    @Environment(\.theme) private var theme

    /// Любая дата показываемого месяца.
    @Binding var month: Date
    let period: AnalyticsPeriod
    let selectedDate: Date
    /// Выделенный период (полуинтервал).
    let selectionStart: Date
    let selectionEnd: Date
    let dayTotals: [Date: Decimal]
    let onSelectDay: (Date) -> Void
    let onSelectWeek: (Date) -> Void
    let onSelectMonth: () -> Void

    private let weekdays = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]
    private var cal: Calendar { Fmt.calendar }

    var body: some View {
        let weeks = weekStarts()
        let maxTotal = dayTotals.values.max() ?? 0

        VStack(spacing: 6) {
            HStack {
                Button {
                    shiftMonth(-1)
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 36, height: 32)
                }
                .accessibilityLabel("Предыдущий месяц")
                Spacer()
                Button(action: onSelectMonth) {
                    Text(Fmt.monthYear(month))
                        .font(.headline)
                        .foregroundStyle(period == .month ? theme.accent : theme.ink)
                }
                Spacer()
                Button {
                    shiftMonth(1)
                } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 36, height: 32)
                }
                .accessibilityLabel("Следующий месяц")
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.accent)

            HStack(spacing: 0) {
                Text("№")
                    .frame(width: 30)
                ForEach(weekdays, id: \.self) { name in
                    Text(name)
                        .frame(maxWidth: .infinity)
                }
            }
            .font(.caption2)
            .foregroundStyle(theme.inkSoft)

            ForEach(weeks, id: \.self) { weekStart in
                HStack(spacing: 0) {
                    Button {
                        onSelectWeek(weekStart)
                    } label: {
                        Text("\(cal.component(.weekOfYear, from: weekStart))")
                            .font(.caption)
                            .foregroundStyle(isSelectedWeek(weekStart) ? theme.accent : theme.inkSoft)
                            .frame(width: 30, height: 40)
                    }
                    .buttonStyle(.plain)
                    ForEach(days(from: weekStart), id: \.self) { day in
                        dayCell(day, maxTotal: maxTotal)
                    }
                }
            }
        }
    }

    // MARK: Части

    private func dayCell(_ day: Date, maxTotal: Decimal) -> some View {
        let inMonth = cal.isDate(day, equalTo: month, toGranularity: .month)
        let isPicked = period == .day && cal.isDate(day, inSameDayAs: selectedDate)
        let inSelection = period != .day && day >= selectionStart && day < selectionEnd
        let isToday = cal.isDateInToday(day)
        let total = dayTotals[cal.startOfDay(for: day)] ?? 0
        let level: Double = maxTotal > 0 ? NSDecimalNumber(decimal: total / maxTotal).doubleValue : 0

        return Button {
            onSelectDay(day)
        } label: {
            VStack(spacing: 3) {
                Text("\(cal.component(.day, from: day))")
                    .font(.subheadline.weight(isToday ? .bold : .regular))
                    .foregroundStyle(isPicked ? theme.onAccent : (inMonth ? theme.ink : theme.inkSoft.opacity(0.5)))
                Circle()
                    .fill(total > 0 ? (isPicked ? theme.onAccent : theme.accent).opacity(0.3 + 0.7 * level) : Color.clear)
                    .frame(width: 5, height: 5)
            }
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isPicked ? theme.accent : (inSelection ? theme.accent.opacity(0.15) : Color.clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func isSelectedWeek(_ weekStart: Date) -> Bool {
        period == .week && cal.isDate(weekStart, inSameDayAs: selectionStart)
    }

    /// Понедельники недель, которые задевают месяц.
    private func weekStarts() -> [Date] {
        guard let monthInterval = cal.dateInterval(of: .month, for: month),
              var weekStart = cal.dateInterval(of: .weekOfYear, for: monthInterval.start)?.start else { return [] }
        var result: [Date] = []
        while weekStart < monthInterval.end {
            result.append(weekStart)
            guard let next = cal.date(byAdding: .day, value: 7, to: weekStart) else { break }
            weekStart = next
        }
        return result
    }

    private func days(from weekStart: Date) -> [Date] {
        (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: weekStart) }
    }

    private func shiftMonth(_ delta: Int) {
        if let next = cal.date(byAdding: .month, value: delta, to: month) {
            month = next
        }
    }
}
