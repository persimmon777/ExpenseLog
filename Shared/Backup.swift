import Foundation

/// Автоматическая резервная копия в папку, выбранную в «Файлах» (CLAUDE.md, раздел 8).
/// Своего iCloud у приложения нет — пишем в папку пользователя (например, iCloud Drive → Spent),
/// доступ к ней хранится закладкой (security-scoped bookmark).
enum Backup {
    /// Сколько последних копий хранить.
    static let keepCount = 10
    /// Не чаще раза в 60 секунд.
    static let minInterval: TimeInterval = 60

    private static var defaults: UserDefaults { AppGroup.defaults }

    static var folderName: String? { defaults.string(forKey: SharedSettings.Key.backupFolderName) }
    static var isConfigured: Bool { defaults.data(forKey: SharedSettings.Key.backupFolderBookmark) != nil }
    static var lastBackupDate: Date? { defaults.object(forKey: SharedSettings.Key.lastBackupDate) as? Date }
    static var lastError: String? { defaults.string(forKey: SharedSettings.Key.backupLastError) }

    /// Запомнить папку (URL из выбора папки).
    static func setFolder(_ url: URL) throws {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        let bookmark = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        defaults.set(bookmark, forKey: SharedSettings.Key.backupFolderBookmark)
        defaults.set(url.lastPathComponent, forKey: SharedSettings.Key.backupFolderName)
        defaults.removeObject(forKey: SharedSettings.Key.backupLastError)
    }

    static func clearFolder() {
        defaults.removeObject(forKey: SharedSettings.Key.backupFolderBookmark)
        defaults.removeObject(forKey: SharedSettings.Key.backupFolderName)
        defaults.removeObject(forKey: SharedSettings.Key.backupLastError)
    }

    /// После изменений и при открытии приложения. Тихо: ошибка запоминается для «Настроек».
    static func runIfNeeded(force: Bool = false) {
        guard isConfigured else { return }
        if !force, let last = lastBackupDate, Date().timeIntervalSince(last) < minInterval { return }
        do {
            try write()
            defaults.set(Date(), forKey: SharedSettings.Key.lastBackupDate)
            defaults.removeObject(forKey: SharedSettings.Key.backupLastError)
        } catch {
            defaults.set("Папка недоступна — выберите её заново.", forKey: SharedSettings.Key.backupLastError)
        }
    }

    private static func resolveFolder() throws -> URL {
        guard let bookmark = defaults.data(forKey: SharedSettings.Key.backupFolderBookmark) else {
            throw CocoaError(.fileNoSuchFile)
        }
        var stale = false
        let url = try URL(resolvingBookmarkData: bookmark, options: [], relativeTo: nil, bookmarkDataIsStale: &stale)
        if stale {
            // Закладка устарела — пересоздаём, пока доступ ещё есть.
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            if let fresh = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) {
                defaults.set(fresh, forKey: SharedSettings.Key.backupFolderBookmark)
            }
        }
        return url
    }

    private static let nameFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd_HH-mm"
        return f
    }()

    private static func write() throws {
        let folder = try resolveFolder()
        guard folder.startAccessingSecurityScopedResource() else { throw CocoaError(.fileReadNoPermission) }
        defer { folder.stopAccessingSecurityScopedResource() }

        guard let raw = DataFile.encode(DataFile.load()) else { throw CocoaError(.fileWriteUnknown) }
        let target = folder.appendingPathComponent("Spent-\(nameFormatter.string(from: Date())).json")

        let coordinator = NSFileCoordinator()
        var coordError: NSError?
        var writeError: Error?
        coordinator.coordinate(writingItemAt: target, options: .forReplacing, error: &coordError) { url in
            do { try raw.write(to: url, options: .atomic) } catch { writeError = error }
        }
        if let error = coordError ?? writeError { throw error }

        prune(folder, coordinator: coordinator)
    }

    /// Оставить последние `keepCount` файлов Spent-*.json.
    private static func prune(_ folder: URL, coordinator: NSFileCoordinator) {
        guard let files = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else { return }
        let backups = files
            .filter { $0.lastPathComponent.hasPrefix("Spent-") && $0.pathExtension.lowercased() == "json" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
        for old in backups.dropFirst(keepCount) {
            var error: NSError?
            coordinator.coordinate(writingItemAt: old, options: .forDeleting, error: &error) { url in
                try? FileManager.default.removeItem(at: url)
            }
        }
    }
}
