import SwiftUI

/// «Регулярные платежи»: подписки, связь, аренда — и поступления (зарплата, стипендия).
struct RecurringView: View {
    @EnvironmentObject private var store: SpentStore
    @Environment(\.theme) private var theme

    @State private var editing: RecurringItem?
    @State private var showNew = false

    var body: some View {
        let data = store.data
        let upcoming = data.upcomingRecurring()
        let paused = data.recurring.filter { !$0.isActive }

        List {
            PaperCard {
                VStack(alignment: .leading, spacing: 8) {
                    AmountRow(title: "Платежи в месяц", value: "−" + Fmt.money(data.recurringMonthly(income: false)), emphasized: true)
                    AmountRow(title: "Поступления в месяц", value: "+" + Fmt.money(data.recurringMonthly(income: true)))
                    RuleLine()
                    AmountRow(title: "Ещё спишется в этом месяце", value: Fmt.money(data.recurringLeftThisMonth(income: false)))
                    AmountRow(title: "Ещё поступит в этом месяце", value: Fmt.money(data.recurringLeftThisMonth(income: true)))
                }
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            Section {
                if upcoming.isEmpty {
                    Text("Добавьте подписки, связь, аренду или зарплату кнопкой «+» — Coin напомнит заранее.")
                        .font(.footnote)
                        .foregroundStyle(theme.inkSoft)
                        .listRowBackground(theme.paper)
                }
                ForEach(upcoming) { entry in
                    row(entry.item, next: entry.next, data: data)
                }
            } header: {
                header("Ближайшие")
            }

            if !paused.isEmpty {
                Section {
                    ForEach(paused) { item in
                        row(item, next: nil, data: data)
                    }
                } header: {
                    header("На паузе")
                }
            }
        }
        .listStyle(.insetGrouped)
        .themedBackground(theme)
        .navigationTitle("Регулярные платежи")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showNew = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Добавить")
            }
        }
        .sheet(item: $editing) { item in
            themed(RecurringEditSheet(item: item))
        }
        .sheet(isPresented: $showNew) {
            themed(RecurringEditSheet(item: nil))
        }
    }

    private func row(_ item: RecurringItem, next: Date?, data: AppData) -> some View {
        let category = data.category(item.categoryID)
        return Button {
            editing = item
        } label: {
            HStack(spacing: 12) {
                Group {
                    if let category {
                        Text(category.emoji)
                    } else {
                        Image(systemName: item.isIncome ? "arrow.down" : "arrow.triangle.2.circlepath")
                            .foregroundStyle(item.isIncome ? theme.positive : theme.inkSoft)
                    }
                }
                .font(.title3)
                .frame(width: 36, height: 36)
                .background(theme.rule.opacity(0.5), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .foregroundStyle(item.isActive ? theme.ink : theme.inkSoft)
                        .lineLimit(1)
                    Text(subtitle(item, next: next))
                        .font(.caption)
                        .foregroundStyle(theme.inkSoft)
                        .lineLimit(2)
                }
                Spacer(minLength: 8)
                Text((item.isIncome ? "+" : "−") + Fmt.money(item.amount, currency: item.currency))
                    .font(theme.amountFont(.body))
                    .foregroundStyle(item.isIncome ? theme.positive : theme.ink)
                    .lineLimit(1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(theme.paper)
        .listRowSeparatorTint(theme.rule)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                let id = item.id
                store.mutate { $0.deleteRecurring(id) }
            } label: {
                Label("Удалить", systemImage: "trash")
            }
        }
    }

    private func subtitle(_ item: RecurringItem, next: Date?) -> String {
        guard let next else { return item.scheduleText }
        if item.isUpcomingPaid(), let paid = item.lastPaidDate {
            return "\(item.scheduleText) · оплачено \(Fmt.dayMonth(paid))"
        }
        let cal = Fmt.calendar
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: next).day ?? 0
        let when: String
        switch days {
        case 0: when = "сегодня"
        case 1: when = "завтра"
        default: when = "\(Fmt.dayMonth(next)), через \(Fmt.plural(days, "день", "дня", "дней"))"
        }
        return "\(item.scheduleText) · следующий \(when)"
    }

    private func header(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(theme.inkSoft)
            .textCase(nil)
    }

    private func themed<V: View>(_ view: V) -> some View {
        view
            .environmentObject(store)
            .environment(\.theme, theme)
            .preferredColorScheme(theme.colorScheme)
            .tint(theme.accent)
    }
}
