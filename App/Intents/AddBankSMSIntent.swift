import AppIntents
import WidgetKit

/// Действие для «Быстрых команд»: автоматизация «Сообщение содержит BYN» передаёт сюда текст SMS.
/// Работает без открытия приложения. SMS, которые не являются операцией, молча пропускаются.
struct AddBankSMSIntent: AppIntent {
    static var title: LocalizedStringResource = "Добавить SMS банка"
    static var description = IntentDescription("Разбирает SMS о списании, пополнении или снятии наличных и добавляет операцию в Spent.")
    static var openAppWhenRun = false

    @Parameter(title: "Текст SMS")
    var text: String

    static var parameterSummary: some ParameterSummary {
        Summary("Добавить в Spent: \(\.$text)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let input = text
        var result = AppData.IngestResult()
        DataFile.update { data in
            result = data.ingest(smsText: input)
        }
        // Дальше по CLAUDE.md: лимиты → еженедельная сводка → резервная копия (появятся на своих шагах).
        WidgetCenter.shared.reloadAllTimelines()
        let summary = result.summary
        SharedSettings.recordAutoAdd(summary)
        return .result(value: summary)
    }
}

/// Готовая команда в приложении «Команды» и для Siri.
struct SpentShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddBankSMSIntent(),
            phrases: ["Добавить SMS в \(.applicationName)"],
            shortTitle: "Добавить SMS банка",
            systemImageName: "text.bubble"
        )
    }
}
