import SwiftUI

/// Настройки. Пока — оформление, магазины и состояние; остальное (CLAUDE.md, 5.5) — на следующих шагах.
struct SettingsView: View {
    @EnvironmentObject private var store: SpentStore
    @Environment(\.theme) private var theme
    @AppStorage(SharedSettings.Key.theme, store: AppGroup.defaults)
    private var themeRaw: String = ThemeID.receipt.rawValue
    @AppStorage(SharedSettings.Key.themePalettes, store: AppGroup.defaults)
    private var themePalettesRaw: String = ""

    @AppStorage(SharedSettings.Key.mascot, store: AppGroup.defaults)
    private var mascotRaw: String = Mascots.randomID
    @AppStorage(SharedSettings.Key.homePeriod, store: AppGroup.defaults)
    private var homePeriodRaw: String = AnalyticsPeriod.day.rawValue

    private var mascotTitle: String {
        switch mascotRaw {
        case Mascots.randomID: return "каждый день новый"
        case Mascots.noneID: return "выключен"
        default: return Mascots.all.first { $0.id == mascotRaw }?.name ?? "каждый день новый"
        }
    }

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
                    Picker("Крупно на главной", selection: $homePeriodRaw) {
                        ForEach(AnalyticsPeriod.allCases) { period in
                            Text(ReceiptSummary.title(period)).tag(period.rawValue)
                        }
                    }
                    NavigationLink {
                        MascotSettingsView()
                    } label: {
                        LabeledContent("Персонаж", value: mascotTitle)
                    }
                    NavigationLink {
                        AppIconSettingsView()
                    } label: {
                        LabeledContent("Иконка приложения", value: AppIconSettingsView.currentTitle)
                    }
                    NavigationLink {
                        RecurringView()
                    } label: {
                        LabeledContent("Регулярные платежи", value: "\(store.data.recurring.filter { $0.isActive }.count)")
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
                        MerchantGroupsView()
                    } label: {
                        LabeledContent("Группы магазинов", value: "\(store.data.merchantGroups.count)")
                    }
                    NavigationLink {
                        MerchantsView()
                    } label: {
                        LabeledContent("Магазины", value: "\(store.data.merchants().count)")
                    }
                }
                Section("Состояние") {
                    NavigationLink {
                        DiagnosticsView()
                    } label: {
                        LabeledContent("Общая папка", value: AppGroup.isShared ? "работает" : "не найдена")
                    }
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
