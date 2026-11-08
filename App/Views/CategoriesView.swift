import SwiftUI

/// Вкладка «Категории»: траты за месяц, лимиты с прогнозом, правила «магазин → категория» (CLAUDE.md, 5.4).
struct CategoriesView: View {
    @EnvironmentObject private var store: SpentStore
    @Environment(\.theme) private var theme

    @State private var editing: Category?
    @State private var showNew = false

    var body: some View {
        let data = store.data

        NavigationStack {
            List {
                Section {
                    ForEach(data.categories) { category in
                        Button {
                            editing = category
                        } label: {
                            row(category, data: data)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(theme.paper)
                        .listRowSeparatorTint(theme.rule)
                    }
                } header: {
                    header(Fmt.monthYear(Date()))
                } footer: {
                    Text("Нажмите на категорию, чтобы изменить её или задать лимит на месяц.")
                        .foregroundStyle(theme.inkSoft)
                }

                Section {
                    if data.rules.isEmpty {
                        Text("Правил пока нет. Они появляются, когда при выборе категории включён переключатель «Всегда относить…».")
                            .font(.footnote)
                            .foregroundStyle(theme.inkSoft)
                            .listRowBackground(theme.paper)
                    }
                    ForEach(data.rules) { rule in
                        ruleRow(rule, data: data)
                            .listRowBackground(theme.paper)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    let id = rule.id
                                    store.mutate { $0.deleteRule(id) }
                                } label: {
                                    Label("Удалить", systemImage: "trash")
                                }
                            }
                    }
                } header: {
                    header("Всегда относить")
                } footer: {
                    if !data.rules.isEmpty {
                        Text("Проведите влево, чтобы удалить правило.")
                            .foregroundStyle(theme.inkSoft)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .themedBackground(theme)
            .navigationTitle("Категории")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showNew = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Новая категория")
                }
            }
            .sheet(item: $editing) { category in
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
            .sheet(isPresented: $showNew) {
                CategoryEditSheet { category in
                    store.mutate { $0.addCategory(category) }
                }
                .environment(\.theme, theme)
                .preferredColorScheme(theme.colorScheme)
                .tint(theme.accent)
            }
        }
    }

    // MARK: Части

    private func row(_ category: Category, data: AppData) -> some View {
        let spent = data.categorySpent(category.id)
        let status = data.limitStatus(for: category)
        return HStack(spacing: 12) {
            Text(category.emoji)
                .font(.title3)
                .frame(width: 36, height: 36)
                .background(Color(hex: category.colorHex).opacity(0.18), in: Circle())
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    Text(category.name)
                        .foregroundStyle(theme.ink)
                    Spacer(minLength: 8)
                    Text(status.map { "\(Fmt.money($0.spent)) из \(Fmt.money($0.limit))" } ?? Fmt.money(spent))
                        .font(theme.amountFont(.subheadline))
                        .foregroundStyle(theme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                if let status {
                    LimitBar(status: status)
                    Text(limitCaption(category, status: status, data: data))
                        .font(.caption)
                        .foregroundStyle(status.level == .over ? theme.danger : theme.inkSoft)
                }
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }

    private func limitCaption(_ category: Category, status: LimitStatus, data: AppData) -> String {
        switch status.level {
        case .over:
            return "Лимит исчерпан"
        case .ok, .warning:
            let percent = Int((status.ratio * 100).rounded())
            if let date = data.limitRunOutDate(for: category) {
                return "\(percent)% · при таком темпе закончится ~\(Fmt.dayMonth(date))"
            }
            return "\(percent)% лимита"
        }
    }

    private func ruleRow(_ rule: MerchantRule, data: AppData) -> some View {
        let category = data.category(rule.categoryID)
        return HStack {
            Text(data.merchantName(rule.displayName))
                .foregroundStyle(theme.ink)
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(category.map { "\($0.emoji) \($0.name)" } ?? "—")
                .foregroundStyle(theme.inkSoft)
                .lineLimit(1)
        }
    }

    private func header(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(theme.inkSoft)
            .textCase(nil)
    }
}
