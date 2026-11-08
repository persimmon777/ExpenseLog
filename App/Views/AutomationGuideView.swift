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
        ("Действие Монетки", "Нажмите «Добавить действие», в поиске введите Монетка и выберите «Добавить SMS банка»."),
        ("Текст SMS — самый важный шаг", "В действии нажмите на бледное слово «Текст SMS». Над клавиатурой появится строка подсказок — нажмите в ней «Ввод быстрой команды» (если её нет, нажмите «Выбрать переменную» и выберите «Ввод быстрой команды»). В поле появится синяя плашка «Ввод быстрой команды»: нажмите на неё и выберите «Содержимое». Должно получиться: «Добавить в Монетку: Содержимое»."),
        ("Готово", "Нажмите «Готово» в правом верхнем углу. Теперь каждая SMS банка с BYN будет сама попадать в Монетку — коды и реклама пропускаются.")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                PaperCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Как это работает")
                            .font(.headline)
                        Text("iPhone не даёт приложениям читать SMS. Но приложение «Команды» умеет запускаться, когда приходит сообщение, и передавать его текст в Монетку. Настраивается один раз, минуты за три.")
                            .font(.subheadline)
                            .foregroundStyle(theme.inkSoft)
                    }
                }

                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    stepRow(number: index + 1, title: step.0, text: step.1)
                }

                PaperCard {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("После SMS появляется окно «Текст»?")
                            .font(.headline)
                        Text("Значит, поле «Текст SMS» в автоматизации пустое и команда спрашивает текст у вас. Откройте «Команды» → «Автоматизация» → вашу автоматизацию «Когда я получаю сообщение, содержащее BYN» → нажмите на действие Монетки и сделайте шаг 8: поле должно показывать синюю плашку «Содержимое». После этого окно больше не появится — текст будет передаваться сам.")
                            .font(.subheadline)
                            .foregroundStyle(theme.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
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
