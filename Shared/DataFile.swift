import Foundation

/// Общая папка приложения и виджета (App Group).
///
/// SideStore при переподписи меняет идентификатор группы (дописывает ID команды)
/// и кладёт настоящий идентификатор в Info.plist под ключом `ALTAppGroups`.
/// Точные разрешённые группы также записаны в профиле подписи `embedded.mobileprovision`.
/// Пробуем всё это по очереди, потом — исходный идентификатор.
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
        return localFolder
    }

    /// Своя папка процесса — туда пишутся данные, если общая папка не найдена.
    static var localFolder: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    static var defaults: UserDefaults {
        if let id = resolvedID, let d = UserDefaults(suiteName: id) { return d }
        return .standard
    }

    static var isShared: Bool { resolvedID != nil }

    /// Папка основного приложения (для виджета — двумя уровнями выше: .app/PlugIns/X.appex).
    private static var mainAppURL: URL? {
        let url = Bundle.main.bundleURL.deletingLastPathComponent().deletingLastPathComponent()
        return url.pathExtension == "app" ? url : nil
    }

    /// Группы из Info.plist (`ALTAppGroups`, их пишет SideStore).
    static var altGroups: [String] {
        var result: [String] = []
        for info in [Bundle.main.infoDictionary, mainAppURL.flatMap { Bundle(url: $0)?.infoDictionary }] {
            for g in (info?["ALTAppGroups"] as? [String]) ?? [] where !result.contains(g) { result.append(g) }
        }
        return result
    }

    /// Группы, разрешённые профилем подписи (`embedded.mobileprovision`) этого бандла и основного приложения.
    static var profileGroups: [String] {
        var result: [String] = []
        for url in [Bundle.main.bundleURL, mainAppURL].compactMap({ $0 }) {
            for g in profileEntitlements(at: url)?["com.apple.security.application-groups"] as? [String] ?? [] where !result.contains(g) {
                result.append(g)
            }
        }
        return result
    }

    /// Разрешения из профиля подписи: внутри файла лежит обычный plist между «<?xml» и «</plist>».
    static func profileEntitlements(at bundleURL: URL) -> [String: Any]? {
        let url = bundleURL.appendingPathComponent("embedded.mobileprovision")
        guard let data = try? Data(contentsOf: url),
              let start = data.range(of: Data("<?xml".utf8)),
              let end = data.range(of: Data("</plist>".utf8), in: start.lowerBound..<data.endIndex) else { return nil }
        let plistData = data.subdata(in: start.lowerBound..<end.upperBound)
        guard let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any] else { return nil }
        return plist["Entitlements"] as? [String: Any]
    }

    static func candidates() -> [String] {
        var result: [String] = []
        for g in altGroups + profileGroups where !result.contains(g) { result.append(g) }
        // Предпочитаем группы, похожие на нашу.
        result.sort { a, b in
            let aa = a.hasPrefix(baseID) ? 0 : 1
            let bb = b.hasPrefix(baseID) ? 0 : 1
            return aa < bb
        }
        if !result.contains(baseID) { result.append(baseID) }
        return result
    }

    /// Текст для экрана «Диагностика» — его владелец присылает, если общая папка не найдена.
    static var diagnostics: String {
        var lines: [String] = []
        lines.append("Bundle ID: \(Bundle.main.bundleIdentifier ?? "—")")
        lines.append("Общая папка: \(resolvedID ?? "не найдена")")
        lines.append("ALTAppGroups: \(altGroups.isEmpty ? "нет" : altGroups.joined(separator: ", "))")
        let profileURL = Bundle.main.bundleURL.appendingPathComponent("embedded.mobileprovision")
        let hasProfile = FileManager.default.fileExists(atPath: profileURL.path)
        lines.append("Профиль подписи: \(hasProfile ? "есть" : "нет")")
        lines.append("Группы в профиле: \(profileGroups.isEmpty ? "нет" : profileGroups.joined(separator: ", "))")
        if let team = profileEntitlements(at: Bundle.main.bundleURL)?["com.apple.developer.team-identifier"] as? String {
            lines.append("Команда: \(team)")
        }
        for candidate in candidates() {
            let ok = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: candidate) != nil
            lines.append("Проверено \(candidate): \(ok ? "доступна" : "нет доступа")")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: Перенос данных в общую папку

    /// Если общая папка появилась, а данные лежали в своей папке приложения — перенести их и настройки.
    /// Вызывается только из приложения при запуске.
    static func migrateLocalDataIfNeeded() {
        guard isShared else { return }
        let fm = FileManager.default
        let local = localFolder.appendingPathComponent("spent-data.json")
        let shared = containerURL.appendingPathComponent("spent-data.json")
        if fm.fileExists(atPath: local.path) {
            let sharedHasData = (try? Data(contentsOf: shared)).map { $0.count > 200 } ?? false
            let localHasData = (try? Data(contentsOf: local)).map { $0.count > 200 } ?? false
            if localHasData && !sharedHasData {
                try? fm.removeItem(at: shared)
                try? fm.copyItem(at: local, to: shared)
            }
            // Старую копию оставляем с другим именем — на всякий случай.
            try? fm.moveItem(at: local, to: localFolder.appendingPathComponent("spent-data-local-backup.json"))
        }
        // Настройки из обычного хранилища → в общее (только те, которых там ещё нет).
        let keys = [SharedSettings.Key.theme, SharedSettings.Key.themePalettes, SharedSettings.Key.backupFolderBookmark,
                    SharedSettings.Key.backupFolderName, SharedSettings.Key.lastBackupDate,
                    SharedSettings.Key.notifyWeeklySummary, SharedSettings.Key.notifyLimits, SharedSettings.Key.notifyDebts,
                    SharedSettings.Key.notifyRecurring, SharedSettings.Key.lastAutoAddDate, SharedSettings.Key.lastAutoAddResult]
        let group = defaults
        for key in keys where group.object(forKey: key) == nil {
            if let value = UserDefaults.standard.object(forKey: key) {
                group.set(value, forKey: key)
            }
        }
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
        static let notifyRecurring = "notifyRecurring"
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
