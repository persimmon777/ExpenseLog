import SwiftUI

/// Настройки. Пока — тема и состояние; остальное (CLAUDE.md, 5.5) — на следующих шагах.
struct SettingsView: View {
    @EnvironmentObject private var store: SpentStore
    @Environment(\.theme) private var theme
    @AppStorage(SharedSettings.Key.theme, store: AppGroup.defaults)
    private var themeRaw: String = ThemeID.receipt.rawValue
    @AppStorage(SharedSettings.Key.themeColors, store: AppGroup.defaults)
    private var themeColorsRaw: String = ""

    private var themeID: ThemeID { ThemeID(rawValue: themeRaw) ?? .receipt }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Тема", selection: $themeRaw) {
                        ForEach(ThemeID.allCases) { id in
                            Text(id.title).tag(id.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    ColorPicker("Фон", selection: colorBinding(.background), supportsOpacity: false)
                    ColorPicker("Основной цвет", selection: colorBinding(.accent), supportsOpacity: false)
                    if hasOverrides {
                        Button("Вернуть цвета темы") { resetColors() }
                    }
                } footer: {
                    Text("Цвета запоминаются отдельно для каждой темы.")
                }
                Section {
                    NavigationLink {
                        MerchantsView()
                    } label: {
                        LabeledContent("Магазины", value: "\(store.data.merchants().count)")
                    }
                } footer: {
                    Text("Свои названия магазинов и категории, к которым они всегда относятся.")
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

    // MARK: Свои цвета темы

    private var hasOverrides: Bool {
        let dict = ThemeColors.decode(themeColorsRaw)
        return dict[ThemeColors.key(themeID, .background)] != nil || dict[ThemeColors.key(themeID, .accent)] != nil
    }

    private func colorBinding(_ slot: ThemeColors.Slot) -> Binding<Color> {
        Binding(
            get: { slot == .background ? theme.background : theme.accent },
            set: { newColor in
                var dict = ThemeColors.decode(themeColorsRaw)
                dict[ThemeColors.key(themeID, slot)] = newColor.hexString()
                themeColorsRaw = ThemeColors.encode(dict)
            }
        )
    }

    private func resetColors() {
        var dict = ThemeColors.decode(themeColorsRaw)
        dict[ThemeColors.key(themeID, .background)] = nil
        dict[ThemeColors.key(themeID, .accent)] = nil
        themeColorsRaw = ThemeColors.encode(dict)
    }
}
