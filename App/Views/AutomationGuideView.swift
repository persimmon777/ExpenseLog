import SwiftUI

/// «Автодобавление из SMS»: пошаговая настройка автоматизации в «Командах» (iOS 17).
struct AutomationGuideView: View {
    @Environment(\.theme) private var theme
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var lastRun = SharedSettings.lastAutoAdd

    private let steps: [(String, String)] = [
        ("Откройте «Команды»", "Это стандартное приложение iPhone. Кнопка ниже откроет его."),
        ("Вкладка «Автоматизация»", "Она внизу экрана. Нажмите «Новая автоматизация» или «+» в правом верхнем углу."),
        ("Выберите «Сообщение»", "Прокрутите список вниз, раздел с событиями на телефоне."),
        ("Условие «Сообщение содержит»", "Нажмите «Выбрать» рядом с ним, введите BYN (заглавными, латиницей) и нажмите «Готово». Отправителя не указывайте."),
        ("Запускать сразу", "Внизу выберите «Запускать сразу» (в некоторых версиях — «Запускать немедленно»). Переключатель «Уведомлять при запуске» можно выключить. Нажмите «Далее»."),
        ("Новая пустая автоматизация", "На следующем экране нажмите «Новая пустая автоматизация»."),
        ("Действие Spent", "Нажмите «Добавить действие», в поиске введите Spent и выберите «Добавить SMS банка»."),
        ("Текст SMS", "Нажмите на синее слово «Текст SMS» в действии и выберите «Ввод быстрой команды». Затем нажмите на появившееся «Ввод быстрой команды» ещё раз и выберите «Содержимое»."),
        ("Готово", "Нажмите «Готово» в правом верхнем углу. Теперь каждая SMS банка с BYN будет сама попадать в Spent — коды и реклама пропускаются.")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                PaperCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Как это работает")
                            .font(.headline)
                        Text("iPhone не даёт приложениям читать SMS. Но приложение «Команды» умеет запускаться, когда приходит сообщение, и передавать его текст в Spent. Настраивается один раз, минуты за три.")
                            .font(.subheadline)
                            .foregroundStyle(theme.inkSoft)
                    }
                }

                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    stepRow(number: index + 1, title: step.0, text: step.1)
                }

                Button {
                    if let url = URL(string: "shortcuts://") { openURL(url) }
                } label: {
                    Label("Открыть «Команды»", systemImage: "arrow.up.forward.app")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)

                PaperCard {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Проверка")
                            .font(.headline)
                        if let lastRun {
                            Text("Последний запуск: \(Fmt.dayTitle(lastRun.date).lowercased()) в \(Fmt.time(lastRun.date))")
                                .font(.subheadline)
                            Text(lastRun.result)
                                .font(.subheadline)
                                .foregroundStyle(theme.inkSoft)
                        } else {
                            Text("Автоматизация ещё не запускалась. Когда придёт SMS банка, здесь появится, что было добавлено.")
                                .font(.subheadline)
                                .foregroundStyle(theme.inkSoft)
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("Автодобавление из SMS")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { lastRun = SharedSettings.lastAutoAdd }
        }
    }

    private func stepRow(number: Int, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(theme.onAccent)
                .frame(width: 28, height: 28)
                .background(theme.accent, in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.ink)
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
