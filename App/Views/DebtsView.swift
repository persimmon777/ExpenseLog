import SwiftUI

/// Вкладка «Долги»: кому, сколько, когда вернуть; «Тебе должны» сверху (CLAUDE.md, 5.3).
struct DebtsView: View {
    @EnvironmentObject private var store: SpentStore
    @Environment(\.theme) private var theme

    @State private var editing: Debt?
    @State private var returning: Debt?
    @State private var showNew = false

    var body: some View {
        let data = store.data
        let active = data.activeDebts
        let returned = data.returnedDebts

        NavigationStack {
            List {
                PaperCard {
                    VStack(alignment: .leading, spacing: 6) {
                        AmountRow(title: "Тебе должны", value: Fmt.money(data.totalOwed), emphasized: true)
                        let overdue = active.filter { $0.isOverdue(calendar: Fmt.calendar) }.count
                        if overdue > 0 {
                            Text("Просрочено: \(overdue)")
                                .font(.caption)
                                .foregroundStyle(theme.danger)
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                Section {
                    if active.isEmpty {
                        Text("Долгов нет. Добавьте кнопкой «+» или из операции — кнопкой «Это долг».")
                            .font(.footnote)
                            .foregroundStyle(theme.inkSoft)
                            .listRowBackground(theme.paper)
                    }
                    ForEach(active) { debt in
                        debtRow(debt)
                    }
                } header: {
                    header("Не вернули")
                }

                if !returned.isEmpty {
                    Section {
                        ForEach(returned) { debt in
                            debtRow(debt)
                        }
                    } header: {
                        header("Вернули")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .themedBackground(theme)
            .navigationTitle("Долги")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showNew = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Добавить долг")
                }
            }
            .sheet(item: $editing) { debt in
                themed(DebtEditSheet(debt: debt))
            }
            .sheet(isPresented: $showNew) {
                themed(DebtEditSheet(debt: nil))
            }
            .sheet(item: $returning) { debt in
                themed(ReturnDebtSheet(debtID: debt.id))
            }
        }
    }

    // MARK: Части

    private func debtRow(_ debt: Debt) -> some View {
        let overdueDays = debt.overdueDays()
        return HStack(spacing: 12) {
            Button {
                if debt.isReturned {
                    let id = debt.id
                    store.mutate { $0.setDebtReturned(id, returned: false) }
                } else {
                    returning = debt
                }
            } label: {
                Image(systemName: debt.isReturned ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(debt.isReturned ? theme.positive : (overdueDays > 0 ? theme.danger : theme.inkSoft))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(debt.isReturned ? "Отметить, что не вернули" : "Отметить, что вернули")

            Button {
                editing = debt
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(debt.person)
                            .foregroundStyle(debt.isReturned ? theme.inkSoft : theme.ink)
                            .lineLimit(1)
                        Text(subtitle(debt, overdueDays: overdueDays))
                            .font(.caption)
                            .foregroundStyle(overdueDays > 0 ? theme.danger : theme.inkSoft)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 8)
                    Text(Fmt.money(debt.amount, currency: debt.currency))
                        .font(theme.amountFont(.body))
                        .foregroundStyle(debt.isReturned ? theme.inkSoft : theme.ink)
                        .strikethrough(debt.isReturned, color: theme.inkSoft)
                        .lineLimit(1)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .listRowBackground(theme.paper)
        .listRowSeparatorTint(theme.rule)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                let id = debt.id
                store.mutate { $0.deleteDebt(id) }
            } label: {
                Label("Удалить", systemImage: "trash")
            }
        }
    }

    private func subtitle(_ debt: Debt, overdueDays: Int) -> String {
        var parts = ["дал \(Fmt.dayMonth(debt.givenDate))"]
        if debt.isReturned {
            if let date = debt.returnedDate { parts.append("вернули \(Fmt.dayMonth(date))") }
        } else if let due = debt.dueDate {
            if overdueDays > 0 {
                parts.append("просрочено на \(Fmt.plural(overdueDays, "день", "дня", "дней"))")
            } else {
                parts.append("вернуть до \(Fmt.dayMonth(due))")
            }
        }
        if let note = debt.note { parts.append(note) }
        return parts.joined(separator: " · ")
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
