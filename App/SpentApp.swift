import SwiftUI

@main
struct SpentApp: App {
    @StateObject private var store = SpentStore()
    @AppStorage(SharedSettings.Key.theme, store: AppGroup.defaults)
    private var themeRaw: String = ThemeID.receipt.rawValue
    @AppStorage(SharedSettings.Key.themePalettes, store: AppGroup.defaults)
    private var themePalettesRaw: String = ""
    @Environment(\.scenePhase) private var scenePhase

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
                    if phase == .active { store.reload() }
                }
        }
    }
}
