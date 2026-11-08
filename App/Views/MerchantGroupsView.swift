import SwiftUI

/// «Группы магазинов»: сети с разными терминалами («SOSEDI 4/3/4», «SOSEDI 12»…) одним названием и категорией.
struct MerchantGroupsView: View {
    @EnvironmentObject private var store: SpentStore
    @Environment(\.theme) private var theme

    @State private var editing: MerchantGroup?
    @State private var showNew = false

    var body: some View {
        let data = store.data
        List {
            Section {
                if data.merchantGroups.isEmpty {
                    Text("Например: название «Соседи», в SMS содержит «SOSEDI», категория «Продукты» — все филиалы будут одним магазином и сами попадут в «Продукты».")
                        .font(.footnote)
                        .foregroundStyle(theme.inkSoft)
                        .listRowBackground(theme.paper)
                }
                ForEach(data.merchantGroups) { group in
                    Button {
                        editing = group
                    } label: {
                        row(group, data: data)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(theme.paper)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            let id = group.id
                            store.mutate { $0.deleteGroup(id) }
                        } label: {
                            Label("Удалить", systemImage: "trash")
                        }
                    }
                }
            } footer: {
                Text("Группа подхватывает и прошлые, и будущие покупки: всё, в названии чего из SMS есть заданный текст.")
                    .foregroundStyle(theme.inkSoft)
            }
        }
        .listStyle(.insetGrouped)
        .themedBackground(theme)
        .navigationTitle("Группы магазинов")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showNew = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Новая группа")
            }
        }
        .sheet(item: $editing) { group in
            themed(MerchantGroupEditSheet(group: group))
        }
        .sheet(isPresented: $showNew) {
            themed(MerchantGroupEditSheet(group: nil))
        }
    }

    private func row(_ group: MerchantGroup, data: AppData) -> some View {
        let stats = data.groupStats(group)
        let category = data.category(group.categoryID)
        return HStack(spacing: 12) {
            Text(category?.emoji ?? "🏪")
                .font(.title3)
                .frame(width: 36, height: 36)
                .background(theme.rule.opacity(0.5), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(group.name)
                    .foregroundStyle(theme.ink)
                Text("содержит «\(group.patternText)» · \(Fmt.plural(stats.count, "покупка", "покупки", "покупок"))\(category.map { " · \($0.name)" } ?? "")")
                    .font(.caption)
                    .foregroundStyle(theme.inkSoft)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            Text(Fmt.money(stats.total))
                .font(theme.amountFont(.body))
                .foregroundStyle(theme.ink)
                .lineLimit(1)
        }
        .contentShape(Rectangle())
    }

    private func themed<V: View>(_ view: V) -> some View {
        view
            .environmentObject(store)
            .environment(\.theme, theme)
            .preferredColorScheme(theme.colorScheme)
            .tint(theme.accent)
    }
}
