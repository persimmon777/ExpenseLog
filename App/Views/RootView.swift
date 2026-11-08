import SwiftUI

/// Пять вкладок (CLAUDE.md, раздел 5).
struct RootView: View {
    @Environment(\.theme) private var theme

    var body: some View {
        TabView {
            ChecksView()
                .tabItem { Label("Чеки", systemImage: "list.bullet.rectangle") }
            PlaceholderView(title: "Аналитика", text: "Календарь, итоги и гистограмма по категориям появятся на следующих шагах.")
                .tabItem { Label("Аналитика", systemImage: "chart.bar") }
            PlaceholderView(title: "Долги", text: "Список долгов и напоминания о возврате появятся на следующих шагах.")
                .tabItem { Label("Долги", systemImage: "person.2") }
            PlaceholderView(title: "Категории", text: "Категории, лимиты и правила появятся на следующих шагах.")
                .tabItem { Label("Категории", systemImage: "square.grid.2x2") }
            SettingsView()
                .tabItem { Label("Настройки", systemImage: "gearshape") }
        }
        .toolbarBackground(theme.paper, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}
