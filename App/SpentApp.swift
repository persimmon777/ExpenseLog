import SwiftUI
import UserNotifications

/// Показывать уведомления и когда приложение открыто (например, «Кафе: потрачено 80% лимита»).
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .list])
    }
}

@main
struct SpentApp: App {
    @StateObject private var store = SpentStore()
    @AppStorage(SharedSettings.Key.theme, store: AppGroup.defaults)
    private var themeRaw: String = ThemeID.receipt.rawValue
    @AppStorage(SharedSettings.Key.themePalettes, store: AppGroup.defaults)
    private var themePalettesRaw: String = ""
    @Environment(\.scenePhase) private var scenePhase

    init() {
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }

    private var theme: Theme {
        Theme.forID(ThemeID(rawValue: themeRaw) ?? .receipt, palettes: ThemePalettes.decode(themePalettesRaw))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environment(\.theme, theme)
                .preferredColorScheme(theme.colorScheme)
                .tint(theme.accent)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { store.becameActive() }
                }
                .task {
                    // Первый запуск: спросить разрешение на уведомления (сводка, лимиты, долги).
                    await Notifier.requestAuthorization()
                    await Notifier.refresh()
                }
        }
    }
}
