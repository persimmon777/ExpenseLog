import SwiftUI

/// Категория: траты за месяц (‹ › листают месяцы), лимит и топ магазинов.
/// Группа магазинов («Соседи») считается одним магазином.
struct CategoryDetailView: View {
    let categoryID: UUID

    @EnvironmentObject private var store: SpentStore
    @Environment(\.theme) private var theme

    @State private var month = Date()
    @State private var editing = false

    var body: some View {
        let data = store.data
        let cal = Fmt.calendar
        let interval = cal.dateInterval(of: .month, for: month)
        let start = interval?.start ?? month
        let end = interval?.end ?? month
        let merchants = data.topMerchants(categoryID: categoryID, from: start, to: end)
        let total = merchants.reduce(Decimal(0)) { $0 + $1.total }

        List {
            if let category = data.category(categoryID) {
                Section {
                    HStack {
                        Button { shift(-1) } label: { Image(systemName: "chevron.left") }
                            .buttonStyle(.plain)
                            .foregroundStyle(theme.accent)
                        Spacer()
                        Text(Fmt.monthYear(start))
                            .font(.headline)
                            .foregroundStyle(theme.ink)
                        Spacer()
                        Button { shift(1) } label: { Image(systemName: "chevron.right") }
                            .buttonStyle(.plain)
                            .foregroundStyle(theme.accent)
                    }
                    .listRowBackground(theme.paper)
                    AmountRow(title: "Потрачено", value: Fmt.money(total), emphasized: true)
                        .listRowBackground(theme.paper)
                    if let limit = category.monthlyLimit, limit > 0 {
                        let status = LimitStatus(spent: total, limit: limit)
                        VStack(alignment: .leading, spacing: 4) {
                            LimitBar(status: status)
                            Text("\(Fmt.money(total)) из \(Fmt.money(limit)) · \(Fmt.percent(status.ratio * 100)) лимита")
                                .font(.caption)
                                .foregroundStyle(status.level == .over ? theme.danger : theme.inkSoft)
                        }
                        .listRowBackground(theme.paper)
                    }
                }

                Section {
                    if merchants.isEmpty {
                        Text("В этом месяце трат в категории нет.")
                            .font(.footnote)
                            .foregroundStyle(theme.inkSoft)
                            .listRowBackground(theme.paper)
                    }
                    ForEach(Array(merchants.enumerated()), id: \.element.id) { index, merchant in
                        NavigationLink {
                            MerchantPeriodView(title: merchant.name, periodTitle: Fmt.monthYear(start),
                                               items: data.expenses(from: start, to: end, categoryID: categoryID, merchantKey: merchant.key))
                        } label: {
                            merchantRow(index: index + 1, merchant: merchant, total: total)
                        }
                        .listRowBackground(theme.paper)
                    }
                } header: {
                    Text("Топ магазинов")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.inkSoft)
                        .textCase(nil)
                } footer: {
                    Text("Филиалы одной сети считаются одним магазином, если для неё есть группа (Настройки → Группы магазинов).")
                        .foregroundStyle(theme.inkSoft)
                }
            } else {
                Text("Категория удалена.")
                    .foregroundStyle(theme.inkSoft)
            }
        }
        .listStyle(.insetGrouped)
        .themedBackground(theme)
        .navigationTitle(data.category(categoryID).map { "\($0.emoji) \($0.name)" } ?? "Категория")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Изменить") { editing = true }
                    .disabled(data.category(categoryID) == nil)
            }
        }
        .sheet(isPresented: $editing) {
            if let category = data.category(categoryID) {
                CategoryEditSheet(
                    category: category,
                    onDelete: {
                        let id = category.id
                        store.mutate { $0.deleteCategory(id) }
                    },
                    onSave: { updated in
                        store.mutate { $0.updateCategory(updated) }
                    }
                )
                .environment(\.theme, theme)
                .preferredColorScheme(theme.colorScheme)
                .tint(theme.accent)
            }
        }
    }

    private func merchantRow(index: Int, merchant: MerchantTotal, total: Decimal) -> some View {
        let share = total > 0 ? NSDecimalNumber(decimal: merchant.total / total * 100).doubleValue : 0
        return HStack(spacing: 12) {
            Text("\(index)")
                .font(.caption.weight(.bold))
                .foregroundStyle(index <= 3 ? theme.onAccent : theme.inkSoft)
                .frame(width: 26, height: 26)
                .background(index <= 3 ? theme.accent : theme.rule.opacity(0.6), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(merchant.name)
                    .foregroundStyle(theme.ink)
                    .lineLimit(1)
                Text("\(Fmt.plural(merchant.count, "покупка", "покупки", "покупок")) · \(Fmt.percent(share))")
                    .font(.caption)
                    .foregroundStyle(theme.inkSoft)
            }
            Spacer(minLength: 8)
            Text(Fmt.money(merchant.total))
                .font(theme.amountFont(.body))
                .foregroundStyle(theme.ink)
                .lineLimit(1)
        }
    }

    private func shift(_ delta: Int) {
        if let next = Fmt.calendar.date(byAdding: .month, value: delta, to: month) {
            month = next
        }
    }
}

/// Покупки одного магазина за период.
struct MerchantPeriodView: View {
    @EnvironmentObject private var store: SpentStore
    @Environment(\.theme) private var theme
    let title: String
    let periodTitle: String
    let items: [Transaction]

    var body: some View {
        let data = store.data
        let total = items.reduce(Decimal(0)) { $0 + $1.amount }
        List {
            Section {
                ForEach(items) { tx in
                    TransactionRow(tx: tx, title: data.displayTitle(for: tx), category: data.category(tx.categoryID))
                        .listRowBackground(theme.paper)
                }
            } header: {
                HStack {
                    Text(periodTitle)
                    Spacer()
                    Text(Fmt.money(total))
                        .font(theme.amountFont(.subheadline))
                        .foregroundStyle(theme.ink)
                }
                .textCase(nil)
            }
        }
        .listStyle(.insetGrouped)
        .themedBackground(theme)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
