import SwiftUI

/// Список всех магазинов: своё название, сколько покупок, сколько потрачено, категория по правилу.
struct MerchantsView: View {
    @EnvironmentObject private var store: SpentStore
    @Environment(\.theme) private var theme

    @State private var search = ""
    @State private var editing: MerchantSummary?
    @State private var editingGroup: MerchantGroup?

    var body: some View {
        let all = store.data.merchants()
        let shown = filtered(all)

        List {
            if all.isEmpty {
                Text("Магазины появятся после первых покупок.")
                    .foregroundStyle(theme.inkSoft)
                    .listRowBackground(theme.paper)
            }
            ForEach(shown) { merchant in
                Button {
                    if let groupID = merchant.groupID {
                        editingGroup = store.data.merchantGroups.first { $0.id == groupID }
                    } else {
                        editing = merchant
                    }
                } label: {
                    row(merchant)
                }
                .buttonStyle(.plain)
                .listRowBackground(theme.paper)
                .listRowSeparatorTint(theme.rule)
            }
        }
        .listStyle(.insetGrouped)
        .themedBackground(theme)
        .navigationTitle("Магазины")
        .searchable(text: $search, prompt: "Поиск")
        .sheet(item: $editingGroup) { group in
            MerchantGroupEditSheet(group: group)
                .environmentObject(store)
                .environment(\.theme, theme)
                .preferredColorScheme(theme.colorScheme)
                .tint(theme.accent)
        }
        .sheet(item: $editing) { merchant in
            MerchantEditSheet(merchantKey: merchant.key, originalName: merchant.originalName)
                .environmentObject(store)
                .environment(\.theme, theme)
                .preferredColorScheme(theme.colorScheme)
                .tint(theme.accent)
        }
    }

    private func filtered(_ list: [MerchantSummary]) -> [MerchantSummary] {
        let q = search.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return list }
        return list.filter {
            $0.name.localizedCaseInsensitiveContains(q) || $0.originalName.localizedCaseInsensitiveContains(q)
        }
    }

    private func row(_ m: MerchantSummary) -> some View {
        let category = store.data.category(m.ruleCategoryID)
        return HStack(spacing: 12) {
            Text(category?.emoji ?? "🏪")
                .font(.title3)
                .frame(width: 36, height: 36)
                .background(theme.rule.opacity(0.5), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(m.name)
                    .foregroundStyle(theme.ink)
                    .lineLimit(1)
                if m.customName != nil {
                    Text(m.originalName)
                        .font(.caption2)
                        .foregroundStyle(theme.inkSoft)
                        .lineLimit(1)
                }
                Text(subtitle(m, category: category))
                    .font(.caption)
                    .foregroundStyle(theme.inkSoft)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(Fmt.money(m.total))
                .font(theme.amountFont(.body))
                .foregroundStyle(theme.ink)
                .lineLimit(1)
        }
        .contentShape(Rectangle())
    }

    private func subtitle(_ m: MerchantSummary, category: Category?) -> String {
        var parts = [Fmt.plural(m.count, "покупка", "покупки", "покупок")]
        if let category { parts.append("всегда «\(category.name)»") }
        parts.append("последняя \(Fmt.dayTitle(m.lastDate).lowercased())")
        return parts.joined(separator: " · ")
    }
}
