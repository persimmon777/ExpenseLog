import Foundation

/// Общая папка приложения и виджета (App Group).
///
/// SideStore при переподписи меняет идентификатор группы (дописывает ID команды)
/// и кладёт настоящий идентификатор в Info.plist под ключом `ALTAppGroups`.
/// Поэтому сначала пробуем его, а потом — исходный.
enum AppGroup {
    static let baseID = "group.com.saevich.spent"

    static let resolvedID: String? = {
        for candidate in AppGroup.candidates() {
            if FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: candidate) != nil {
                return candidate
            }
        }
        return nil
    }()

    static var containerURL: URL {
        if let id = resolvedID,
           let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id) {
            return url
        }
        // Запасной вариант: своя папка процесса (виджет тогда данных не увидит).
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    static var defaults: UserDefaults {
        if let id = resolvedID, let d = UserDefaults(suiteName: id) { return d }
        return .standard
    }

    static var isShared: Bool { resolvedID != nil }

    private static func candidates() -> [String] {
        var result: [String] = []
        func collect(from info: [String: Any]?) {
            if let groups = info?["ALTAppGroups"] as? [String] {
                for g in groups where !result.contains(g) { result.append(g) }
            }
        }
        collect(from: Bundle.main.infoDictionary)
        // Для виджета: Info.plist основного приложения лежит двумя папками выше (.app/PlugIns/X.appex).
        let mainAppURL = Bundle.main.bundleURL.deletingLastPathComponent().deletingLastPathComponent()
        if mainAppURL.pathExtension == "app", let appBundle = Bundle(url: mainAppURL) {
            collect(from: appBundle.infoDictionary)
        }
        // Предпочитаем группы, похожие на нашу.
        result.sort { a, b in
            let aa = a.hasPrefix(baseID) ? 0 : 1
            let bb = b.hasPrefix(baseID) ? 0 : 1
            return aa < bb
        }
        if !result.contains(baseID) { result.append(baseID) }
        return result
    }
}

/// Чтение и запись данных в JSON-файл в общей папке.
enum DataFile {
    private static let lock = NSLock()

    static var url: URL {
        AppGroup.containerURL.appendingPathComponent("spent-data.json")
    }

    static func load() -> AppData {
        lock.lock()
        defer { lock.unlock() }
        return loadUnlocked()
    }

    static func save(_ data: AppData) {
        lock.lock()
        defer { lock.unlock() }
        saveUnlocked(data)
    }

    /// Прочитать свежие данные с диска, изменить и сразу записать.
    /// Так приложение не затрёт покупку, которую только что добавила «Быстрая команда».
    @discardableResult
    static func update(_ change: (inout AppData) -> Void) -> AppData {
        lock.lock()
        defer { lock.unlock() }
        var data = loadUnlocked()
        change(&data)
        saveUnlocked(data)
        return data
    }

    private static func loadUnlocked() -> AppData {
        let fileURL = url
        guard let raw = try? Data(contentsOf: fileURL) else {
            let fresh = AppData()
            saveUnlocked(fresh)
            return fresh
        }
        do {
            return try JSONDecoder().decode(AppData.self, from: raw)
        } catch {
            // Файл повреждён: сохраняем копию, чтобы ничего не потерять, и начинаем заново.
            let backup = fileURL.deletingLastPathComponent()
                .appendingPathComponent("spent-data-broken-\(Int(Date().timeIntervalSince1970)).json")
            try? raw.write(to: backup)
            let fresh = AppData()
            saveUnlocked(fresh)
            return fresh
        }
    }

    private static func saveUnlocked(_ data: AppData) {
        guard let raw = encode(data) else { return }
        try? raw.write(to: url, options: [.atomic])
    }

    /// JSON всех данных — для резервной копии и экспорта.
    static func encode(_ data: AppData) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(data)
    }

    /// Прочитать данные из файла копии. `nil` — это не файл Spent.
    static func decodeBackup(_ raw: Data) -> AppData? {
        // Пустой JSON «{}» тоже прочитался бы — проверяем, что в файле действительно данные Spent.
        guard let dict = try? JSONSerialization.jsonObject(with: raw) as? [String: Any],
              dict["transactions"] != nil || dict["categories"] != nil else { return nil }
        return try? JSONDecoder().decode(AppData.self, from: raw)
    }
}

/// Настройки в UserDefaults общей группы (тема нужна и виджету).
/// Данные (операции, категории, долги) сюда не кладём — только в `DataFile`.
enum SharedSettings {
    enum Key {
        static let theme = "theme"
        /// Выбранная палитра каждой темы, JSON — см. `ThemePalettes`.
        static let themePalettes = "themePalettes"
        /// Security-scoped bookmark папки для автокопий (см. CLAUDE.md, «Резервная копия»).
        static let backupFolderBookmark = "backupFolderBookmark"
        static let lastBackupDate = "lastBackupDate"
        static let backupFolderName = "backupFolderName"
        static let backupLastError = "backupLastError"
        static let notifyWeeklySummary = "notifyWeeklySummary"
        static let notifyLimits = "notifyLimits"
        static let notifyDebts = "notifyDebts"
        /// Когда последний раз сработала команда «Добавить SMS банка» и что она сделала.
        static let lastAutoAddDate = "lastAutoAddDate"
        static let lastAutoAddResult = "lastAutoAddResult"
    }

    /// Запомнить последний запуск автодобавления (для экрана-инструкции).
    static func recordAutoAdd(_ result: String, date: Date = Date()) {
        AppGroup.defaults.set(date, forKey: Key.lastAutoAddDate)
        AppGroup.defaults.set(result, forKey: Key.lastAutoAddResult)
    }

    static var lastAutoAdd: (date: Date, result: String)? {
        guard let date = AppGroup.defaults.object(forKey: Key.lastAutoAddDate) as? Date else { return nil }
        return (date, AppGroup.defaults.string(forKey: Key.lastAutoAddResult) ?? "")
    }

    static var themeID: ThemeID {
        get { ThemeID(rawValue: AppGroup.defaults.string(forKey: Key.theme) ?? "") ?? .receipt }
        set { AppGroup.defaults.set(newValue.rawValue, forKey: Key.theme) }
    }

    /// Уведомления включены по умолчанию — пока пользователь не выключил.
    static func isEnabled(_ key: String) -> Bool {
        AppGroup.defaults.object(forKey: key) as? Bool ?? true
    }
}
