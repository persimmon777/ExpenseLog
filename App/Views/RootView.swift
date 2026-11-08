import SwiftUI

/// Пять вкладок (CLAUDE.md, раздел 5).
struct RootView: View {
    @Environment(\.theme) private var theme

    var body: some View {
        TabView {
            ChecksView()
                .tabItem { Label("Чеки", systemImage: "list.bullet.rectangle") }
            AnalyticsView()
                .tabItem { Label("Аналитика", systemImage: "chart.bar") }
            DebtsView()
                .tabItem { Label("Долги", systemImage: "person.2") }
            CategoriesView()
                .tabItem { Label("Категории", systemImage: "square.grid.2x2") }
            SettingsView()
                .tabItem { Label("Настройки", systemImage: "gearshape") }
        }
        .toolbarBackground(theme.paper, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}
