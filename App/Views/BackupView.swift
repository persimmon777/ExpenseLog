import SwiftUI
import UniformTypeIdentifiers

/// «Резервная копия»: папка для автокопий, «Сделать копию сейчас», восстановление, экспорт вручную.
struct BackupView: View {
    @EnvironmentObject private var store: SpentStore
    @Environment(\.theme) private var theme
    @Environment(\.scenePhase) private var scenePhase

    private enum PickerMode {
        case folder, restore
    }

    @State private var pickerMode: PickerMode = .folder
    @State private var showPicker = false
    @State private var refreshID = UUID()
    @State private var pendingRestore: AppData?
    @State private var showRestoreConfirm = false
    @State private var message: String?
    @State private var exportURL: URL?

    var body: some View {
        let _ = refreshID
        Form {
            Section {
                LabeledContent("Папка", value: Backup.folderName ?? "не выбрана")
                if let date = Backup.lastBackupDate, Backup.isConfigured {
                    LabeledContent("Последняя копия", value: "\(Fmt.dayTitle(date).lowercased()) в \(Fmt.time(date))")
                }
                if let error = Backup.lastError {
                    Text(error)
                        .foregroundStyle(theme.danger)
                }
                Button(Backup.isConfigured ? "Выбрать другую папку" : "Выбрать папку") {
                    pickerMode = .folder
                    showPicker = true
                }
                if Backup.isConfigured {
                    Button("Сделать копию сейчас") {
                        Backup.runIfNeeded(force: true)
                        message = Backup.lastError == nil ? "Копия сохранена." : nil
                        refreshID = UUID()
                    }
                    Button("Не делать копии", role: .destructive) {
                        Backup.clearFolder()
                        refreshID = UUID()
                    }
                }
            } header: {
                Text("Автоматическая копия")
            } footer: {
                Text("Удобнее всего: «Файлы» → iCloud Drive → создайте папку Coin и выберите её. Копия сохраняется при каждом открытии приложения и после изменений (не чаще раза в минуту), хранятся последние 10. Если телефон потеряется — данные останутся в iCloud.")
            }

            Section {
                Button("Восстановить из копии") {
                    pickerMode = .restore
                    showPicker = true
                }
            } footer: {
                Text("Выберите файл Spent-….json. Текущие данные будут заменены данными из копии.")
            }

            Section {
                if let exportURL {
                    ShareLink(item: exportURL) {
                        Label("Отправить файл с данными", systemImage: "square.and.arrow.up")
                    }
                } else {
                    Button("Подготовить файл с данными") { prepareExport() }
                }
            } header: {
                Text("Перенос вручную")
            } footer: {
                Text("Файл можно сохранить в «Файлы» или отправить себе в Telegram. Загрузить его обратно — кнопкой «Восстановить из копии».")
            }

            if let message {
                Section {
                    Text(message)
                        .foregroundStyle(theme.positive)
                }
            }
        }
        .themedBackground(theme)
        .navigationTitle("Резервная копия")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $showPicker,
            allowedContentTypes: pickerMode == .folder ? [.folder] : [.json, .item],
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            switch pickerMode {
            case .folder: chooseFolder(url)
            case .restore: readBackup(url)
            }
        }
        .confirmationDialog("Заменить данные?", isPresented: $showRestoreConfirm, titleVisibility: .visible) {
            Button("Заменить данные", role: .destructive) { restore() }
            Button("Отменить", role: .cancel) { pendingRestore = nil }
        } message: {
            Text(restoreSummary)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refreshID = UUID() }
        }
    }

    // MARK: Действия

    private var restoreSummary: String {
        guard let data = pendingRestore else { return "" }
        return "Текущие данные будут заменены. В копии: \(Fmt.plural(data.transactions.count, "операция", "операции", "операций")), \(Fmt.plural(data.categories.count, "категория", "категории", "категорий"))."
    }

    private func chooseFolder(_ url: URL) {
        do {
            try Backup.setFolder(url)
            Backup.runIfNeeded(force: true)
            message = Backup.lastError == nil ? "Папка выбрана, первая копия сохранена." : nil
        } catch {
            message = nil
            AppGroup.defaults.set("Не удалось запомнить папку — попробуйте другую.", forKey: SharedSettings.Key.backupLastError)
        }
        refreshID = UUID()
    }

    private func readBackup(_ url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        guard let raw = try? Data(contentsOf: url), let data = DataFile.decodeBackup(raw) else {
            message = nil
            AppGroup.defaults.set("Это не файл копии Coin.", forKey: SharedSettings.Key.backupLastError)
            refreshID = UUID()
            return
        }
        pendingRestore = data
        showRestoreConfirm = true
    }

    private func restore() {
        guard let data = pendingRestore else { return }
        DataFile.save(data)
        store.becameActive()
        pendingRestore = nil
        message = "Данные восстановлены из копии."
    }

    private func prepareExport() {
        guard let raw = DataFile.encode(store.data) else { return }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd_HH-mm"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Spent-\(formatter.string(from: Date())).json")
        do {
            try raw.write(to: url, options: .atomic)
            exportURL = url
        } catch {
            message = nil
        }
    }
}
