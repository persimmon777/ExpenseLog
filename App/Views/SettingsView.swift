import SwiftUI

/// Настройки. Пока — тема и состояние; остальное (CLAUDE.md, 5.5) — на следующих шагах.
struct SettingsView: View {
    @EnvironmentObject private var store: SpentStore
    @Environment(\.theme) private var theme
    @AppStorage(SharedSettings.Key.theme, store: AppGroup.defaults)
    private var themeRaw: String = ThemeID.receipt.rawValue

    var body: some View {
        NavigationStack {
            Form {
                Section("Тема") {
                    Picker("Тема", selection: $themeRaw) {
                        ForEach(ThemeID.allCases) { id in
                            Text(id.title).tag(id.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section("Состояние") {
                    LabeledContent("Общая папка", value: AppGroup.isShared ? "работает" : "не найдена")
                    LabeledContent("Операций", value: "\(store.data.transactions.count)")
                    LabeledContent("Категорий", value: "\(store.data.categories.count)")
                    LabeledContent("Правил", value: "\(store.data.rules.count)")
                }
                Section {
                    Text(AppGroup.resolvedID ?? "—")
                        .font(.caption)
                        .foregroundStyle(theme.inkSoft)
                } header: {
                    Text("Группа")
                } footer: {
                    Text("Если написано «не найдена», виджет не увидит данные. В SideStore должна быть включена настройка Auto-Fix AppGroup IDs.")
                }
            }
            .themedBackground(theme)
            .navigationTitle("Настройки")
        }
    }
}
