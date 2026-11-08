import SwiftUI
import UniformTypeIdentifiers

/// «Импорт истории SMS»: старые SMS банка из резервной копии iPhone или текстового файла.
struct ImportHistoryView: View {
    @EnvironmentObject private var store: SpentStore
    @Environment(\.theme) private var theme

    @State private var showPicker = false
    @State private var isLoading = false
    @State private var found: [ParsedSMS] = []
    @State private var texts: [String] = []
    @State private var fileName: String?
    @State private var errorText: String?
    @State private var resultText: String?
    @State private var useMCC = true

    private let steps: [(String, String)] = [
        ("Сделайте резервную копию на компьютере", "Установите «Устройства Apple» (Apple Devices) из Microsoft Store или iTunes. Подключите iPhone кабелем, выберите «Создавать резервные копии всех данных на этом компьютере», галочку «Шифровать» снимите, нажмите «Создать резервную копию сейчас»."),
        ("Найдите файл сообщений", "Откройте в Проводнике папку %USERPROFILE%\\Apple\\MobileSync\\Backup (для iTunes с сайта Apple — %APPDATA%\\Apple Computer\\MobileSync\\Backup). Внутри — папка с длинным именем, в ней папка 3d, в ней файл 3d0d7e5fb2ce288813306e4d4636395e047a3d28. Это все ваши сообщения."),
        ("Перекиньте файл на iPhone", "Проще всего — отправить его себе в Telegram в «Избранное», затем на телефоне открыть файл → «Поделиться» → «Сохранить в Файлы». Подойдёт и iCloud Drive через сайт icloud.com."),
        ("Выберите файл здесь", "Нажмите «Выбрать файл» ниже. Spent найдёт в нём все SMS банка, покажет, сколько операций и за какой период, и добавит их. Остальные сообщения не читаются и никуда не отправляются.")
    ]

    var body: some View {
        let data = store.data
        let newOnes = found.filter { data.previewStatus($0) == .new }
        let newCount = Set(newOnes.map(\.fingerprint)).count

        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                PaperCard {
                    Text("iPhone не даёт приложениям читать «Сообщения». Но все SMS есть в резервной копии телефона на компьютере — оттуда их можно один раз перенести в Spent.")
                        .font(.subheadline)
                        .foregroundStyle(theme.inkSoft)
                }

                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    stepRow(number: index + 1, title: step.0, text: step.1)
                }

                Button {
                    showPicker = true
                } label: {
                    Label(isLoading ? "Читаю файл…" : "Выбрать файл", systemImage: "doc.badge.plus")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoading)

                if let errorText {
                    Text(errorText)
                        .font(.subheadline)
                        .foregroundStyle(theme.danger)
                }

                if fileName != nil {
                    previewCard(newOnes: newOnes, newCount: newCount)
                }

                PaperCard {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Есть текстовый файл с SMS?")
                            .font(.headline)
                        Text("Экспорт чата в .txt или .csv из другой программы тоже подойдёт — выберите его кнопкой выше. А несколько отдельных SMS можно вставить на экране «Чеки» кнопкой «Вставить SMS».")
                            .font(.subheadline)
                            .foregroundStyle(theme.inkSoft)
                    }
                }
            }
            .padding(16)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("Импорт истории SMS")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(isPresented: $showPicker, allowedContentTypes: [.item], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first { load(url) }
            case .failure(let error):
                errorText = error.localizedDescription
            }
        }
    }

    // MARK: Части

    private func previewCard(newOnes: [ParsedSMS], newCount: Int) -> some View {
        let dates = found.compactMap(\.date)
        let expenses = newOnes.filter { $0.type == .payment }.reduce(Decimal(0)) { $0 + $1.amount }
        return PaperCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(fileName ?? "")
                    .font(.caption)
                    .foregroundStyle(theme.inkSoft)
                    .lineLimit(1)
                AmountRow(title: "Найдено операций", value: "\(found.count)", emphasized: true)
                if let first = dates.min(), let last = dates.max() {
                    AmountRow(title: "Период", value: "\(Fmt.dayMonth(first)) \(Fmt.calendar.component(.year, from: first)) – \(Fmt.dayMonth(last)) \(Fmt.calendar.component(.year, from: last))")
                }
                AmountRow(title: "Новых", value: "\(newCount)")
                if found.count > newCount {
                    Text("Остальные уже есть в Spent или вы их удаляли — второй раз не добавятся.")
                        .font(.caption)
                        .foregroundStyle(theme.inkSoft)
                }
                if expenses > 0 {
                    AmountRow(title: "Из них оплат на", value: Fmt.money(expenses))
                }
                RuleLine()
                Toggle(isOn: $useMCC) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Сразу разложить по категориям")
                            .font(.subheadline)
                        Text("По коду магазина из SMS (MCC): продукты, кафе, транспорт… Остальное попадёт в «Без категории».")
                            .font(.caption)
                            .foregroundStyle(theme.inkSoft)
                    }
                }
                .tint(theme.accent)
                if let resultText {
                    Text(resultText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.positive)
                } else if newCount > 0 {
                    Button {
                        add()
                    } label: {
                        Text("Добавить \(Fmt.plural(newCount, "операцию", "операции", "операций"))")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
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
                    .textSelection(.enabled)
            }
        }
    }

    // MARK: Действия

    private func load(_ url: URL) {
        isLoading = true
        errorText = nil
        resultText = nil
        fileName = nil
        Task.detached(priority: .userInitiated) {
            let outcome: Result<[String], Error>
            do {
                outcome = .success(try SMSHistoryImporter.messages(from: url))
            } catch {
                outcome = .failure(error)
            }
            await MainActor.run {
                isLoading = false
                switch outcome {
                case .success(let list):
                    texts = list
                    found = list.compactMap(SMSParser.parse)
                    fileName = url.lastPathComponent
                    if found.isEmpty {
                        errorText = "В файле не нашлось SMS банка с BYN. Проверьте, что выбран нужный файл."
                        fileName = nil
                    }
                case .failure(let error):
                    errorText = error.localizedDescription
                }
            }
        }
    }

    private func add() {
        let input = texts.joined(separator: "\n\n")
        let applyMCC = useMCC
        let summary = store.mutate { (data: inout AppData) -> (Int, Int) in
            let result = data.ingest(smsText: input)
            let ids = Set(result.added.map(\.id))
            let sorted = applyMCC ? data.applyMCCSuggestions(to: ids) : 0
            return (result.added.count, sorted)
        }
        var text = "Добавлено \(summary.0)"
        if applyMCC { text += ", разложено по категориям \(summary.1)" }
        resultText = text + ". Остальное — в «Без категории» на экране «Чеки»."
    }
}
