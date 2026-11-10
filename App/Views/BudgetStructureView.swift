import SwiftUI

/// «Структура бюджета»: сколько из бюджета на месяц заложено на каждую категорию (конверт).
/// Сумма конверта — это и есть лимит категории (`Category.monthlyLimit`): полоска и уведомления 80% / 100%.
struct BudgetStructureView: View {
    @EnvironmentObject private var store: SpentStore
    @Environment(\.theme) private var theme

    /// Введённые суммы: id категории → текст.
    @State private var texts: [UUID: String] = [:]
    @State private var loaded = false

    var body: some View {
        let data = store.data
        let budget = data.monthBudget(containing: Date())
        let allocated = data.categories.reduce(Decimal(0)) { $0 + (amount(for: $1.id) ?? 0) }

        List {
            Section {
                AmountRow(title: "Бюджет на месяц", value: budget.map { Fmt.money($0) } ?? "не задан", emphasized: true)
                    .listRowBackground(theme.paper)
                AmountRow(title: "В конвертах", value: Fmt.money(allocated))
                    .listRowBackground(theme.paper)
                if let budget {
                    AmountRow(title: "Свободные деньги", value: Fmt.money(budget - allocated))
                        .foregroundStyle(budget - allocated < 0 ? theme.danger : theme.ink)
                        .listRowBackground(theme.paper)
                }
            } footer: {
                if let budget, allocated > budget {
                    Text("В конверты разложено больше, чем весь бюджет, на \(Fmt.money(allocated - budget)). Уменьшите конверты или увеличьте бюджет.")
                        .foregroundStyle(theme.danger)
                } else {
                    Text("Свободные деньги — всё, что не в конвертах. Из них считается «Можно сегодня», туда же уходит перерасход конвертов.")
                        .foregroundStyle(theme.inkSoft)
                }
            }

            Section {
                ForEach(data.categories) { category in
                    HStack(spacing: 10) {
                        Text("\(category.emoji) \(category.name)")
                            .foregroundStyle(theme.ink)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        TextField("—", text: binding(category.id))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(theme.amountFont(.body))
                            .frame(maxWidth: 110)
                        Text("BYN")
                            .font(.caption)
                            .foregroundStyle(theme.inkSoft)
                    }
                    .listRowBackground(theme.paper)
                }
            } header: {
                Text("Конверты на месяц")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.inkSoft)
                    .textCase(nil)
            } footer: {
                Text("Пустое поле — категория без конверта, её траты идут из свободных денег. Сумма конверта — это и лимит категории.")
                    .foregroundStyle(theme.inkSoft)
            }

            Section {
                Button("Сохранить") { save() }
                    .disabled(!hasChanges(data))
                    .listRowBackground(theme.paper)
            }
        }
        .listStyle(.insetGrouped)
        .themedBackground(theme)
        .navigationTitle("Структура бюджета")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Готово") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
        }
        .onAppear {
            guard !loaded else { return }
            loaded = true
            for category in store.data.categories {
                texts[category.id] = category.monthlyLimit.map(WeeklyPlanView.text) ?? ""
            }
        }
    }

    private func binding(_ id: UUID) -> Binding<String> {
        Binding(get: { texts[id] ?? "" }, set: { texts[id] = $0 })
    }

    private func amount(for id: UUID) -> Decimal? {
        MonthlyBudgetSections.parse(texts[id] ?? "")
    }

    private func hasChanges(_ data: AppData) -> Bool {
        data.categories.contains { amount(for: $0.id) != $0.monthlyLimit }
    }

    private func save() {
        let values = store.data.categories.map { ($0.id, amount(for: $0.id)) }
        store.mutate { data in
            for (id, value) in values {
                data.setEnvelope(value, categoryID: id)
            }
        }
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
