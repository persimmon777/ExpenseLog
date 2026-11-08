import SwiftUI
import UIKit

/// Вкладка «Аналитика»: календарь, итог периода, гистограмма по категориям,
/// пополнения / переводы / долги отдельно, «Поделиться» (CLAUDE.md, 5.2).
struct AnalyticsView: View {
    @EnvironmentObject private var store: SpentStore
    @Environment(\.theme) private var theme
    @Environment(\.openURL) private var openURL

    @State private var period: AnalyticsPeriod = .month
    @State private var selectedDate = Date()
    @State private var displayedMonth = Date()
    @State private var toast: String?

    var body: some View {
        let data = store.data
        let summary = data.summary(period, containing: selectedDate)
        let calendarRange = calendarBounds()
        let dayTotals = data.dayTotals(from: calendarRange.start, to: calendarRange.end)

        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Picker("Период", selection: $period) {
                        ForEach(AnalyticsPeriod.allCases) { p in
                            Text(p.title).tag(p)
                        }
                    }
                    .pickerStyle(.segmented)

                    PaperCard {
                        MonthCalendarView(
                            month: $displayedMonth,
                            period: period,
                            selectedDate: selectedDate,
                            selectionStart: summary.start,
                            selectionEnd: summary.end,
                            dayTotals: dayTotals,
                            onSelectDay: { day in
                                selectedDate = day
                                period = .day
                                displayedMonth = day
                            },
                            onSelectWeek: { weekStart in
                                selectedDate = weekStart
                                period = .week
                            },
                            onSelectMonth: {
                                selectedDate = Fmt.calendar.isDate(displayedMonth, equalTo: Date(), toGranularity: .month) ? Date() : displayedMonth
                                period = .month
                            }
                        )
                    }

                    totalCard(summary)

                    if !summary.categories.isEmpty {
                        categoriesCard(summary)
                    }

                    otherCard(summary, data: data)
                }
                .padding(16)
            }
            .background(theme.background.ignoresSafeArea())
            .navigationTitle("Аналитика")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ShareLink(item: data.reportText(summary)) {
                            Label("Отправить отчёт", systemImage: "square.and.arrow.up")
                        }
                        Button {
                            askDeepSeek(data.deepSeekText(summary))
                        } label: {
                            Label("Разобрать в DeepSeek", systemImage: "sparkles")
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Поделиться")
                }
            }
            .overlay(alignment: .bottom) {
                if let toast {
                    Text(toast)
                        .font(.subheadline)
                        .foregroundStyle(theme.paper)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(theme.ink, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .padding(16)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }

    // MARK: Карточки

    private func totalCard(_ s: PeriodSummary) -> some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(s.title)
                    .font(.caption)
                    .foregroundStyle(theme.inkSoft)
                AmountRow(title: "Потрачено", value: Fmt.money(s.total), emphasized: true)
                Text(Fmt.plural(s.count, "покупка", "покупки", "покупок"))
                    .font(.subheadline)
                    .foregroundStyle(theme.inkSoft)
                if let comparison = s.comparisonText {
                    Text(comparison)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle((s.changePercent ?? 0) > 0 ? theme.danger : theme.positive)
                }
            }
        }
    }

    private func categoriesCard(_ s: PeriodSummary) -> some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("По категориям")
                    .font(.headline)
                CategoryChart(summary: s)
                RuleLine()
                ForEach(s.categories) { item in
                    NavigationLink {
                        CategoryPeriodView(categoryID: item.categoryID, title: item.name, periodTitle: s.title, start: s.start, end: s.end)
                    } label: {
                        HStack {
                            Text("\(item.emoji) \(item.name)")
                                .foregroundStyle(theme.ink)
                                .lineLimit(1)
                            Spacer(minLength: 8)
                            Text(Fmt.money(item.total))
                                .font(theme.amountFont(.subheadline))
                                .foregroundStyle(theme.ink)
                            Text("\(s.percent(of: item.total))%")
                                .font(.caption)
                                .foregroundStyle(theme.inkSoft)
                                .frame(width: 38, alignment: .trailing)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(theme.inkSoft)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    /// Не смешиваем с расходами: пополнения, переводы, долги.
    private func otherCard(_ s: PeriodSummary, data: AppData) -> some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Не входит в расходы")
                    .font(.headline)
                AmountRow(title: "Пополнения", value: "+" + Fmt.money(s.income))
                AmountRow(title: "Переводы", value: Fmt.money(s.transfers))
                AmountRow(title: "Дал в долг", value: Fmt.money(s.debtGiven))
                RuleLine()
                AmountRow(title: "Тебе должны сейчас", value: Fmt.money(data.totalOwed))
            }
        }
    }

    // MARK: Действия

    /// Неделя с понедельника: точки нужны для всех дней, видимых в сетке месяца.
    private func calendarBounds() -> (start: Date, end: Date) {
        let cal = Fmt.calendar
        guard let month = cal.dateInterval(of: .month, for: displayedMonth) else { return (displayedMonth, displayedMonth) }
        let start = cal.dateInterval(of: .weekOfYear, for: month.start)?.start ?? month.start
        let lastDay = cal.date(byAdding: .day, value: -1, to: month.end) ?? month.end
        let end = cal.dateInterval(of: .weekOfYear, for: lastDay)?.end ?? month.end
        return (start, end)
    }

    private func askDeepSeek(_ text: String) {
        UIPasteboard.general.string = text
        withAnimation { toast = "Отчёт скопирован — вставь его в чат DeepSeek" }
        if let url = URL(string: "https://chat.deepseek.com") {
            openURL(url)
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            withAnimation { toast = nil }
        }
    }
}
