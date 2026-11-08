import SwiftUI

/// Настройки. Пока — оформление, магазины и состояние; остальное (CLAUDE.md, 5.5) — на следующих шагах.
struct SettingsView: View {
    @EnvironmentObject private var store: SpentStore
    @Environment(\.theme) private var theme
    @AppStorage(SharedSettings.Key.theme, store: AppGroup.defaults)
    private var themeRaw: String = ThemeID.receipt.rawValue
    @AppStorage(SharedSettings.Key.themePalettes, store: AppGroup.defaults)
    private var themePalettesRaw: String = ""

    var body: some View {
        let themeID = ThemeID(rawValue: themeRaw) ?? .receipt
        let palette = themeID.palette(withID: ThemePalettes.decode(themePalettesRaw)[themeID.rawValue])

        NavigationStack {
            Form {
                Section {
                    NavigationLink {
                        ThemeSettingsView()
                    } label: {
                        LabeledContent("Оформление", value: "\(themeID.title) · \(palette.name)")
                    }
                    NavigationLink {
                        WeeklyPlanView()
                    } label: {
                        LabeledContent("План трат", value: store.data.currentBasePlan.map { "\(Fmt.money($0)) в неделю" } ?? "не задан")
                    }
                    NavigationLink {
                        BackupView()
                    } label: {
                        LabeledContent("Резервная копия", value: Backup.isConfigured ? (Backup.lastError == nil ? "включена" : "ошибка") : "выключена")
                    }
                    NavigationLink {
                        NotificationSettingsView()
                    } label: {
                        Text("Уведомления")
                    }
                    NavigationLink {
                        AutomationGuideView()
                    } label: {
                        LabeledContent("Автодобавление из SMS", value: SharedSettings.lastAutoAdd == nil ? "не настроено" : "работает")
                    }
                    NavigationLink {
                        ImportHistoryView()
                    } label: {
                        Text("Импорт истории SMS")
                    }
                    NavigationLink {
                        MerchantsView()
                    } label: {
                        LabeledContent("Магазины", value: "\(store.data.merchants().count)")
                    }
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
