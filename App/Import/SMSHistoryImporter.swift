import Foundation
import SQLite3

/// Чтение старых SMS из файла: база сообщений iPhone из резервной копии (sms.db)
/// или любой текстовый файл (экспорт чата, заметка).
enum SMSHistoryImporter {

    enum ImportError: LocalizedError {
        case unreadable
        case database(String)

        var errorDescription: String? {
            switch self {
            case .unreadable: return "Не удалось прочитать файл."
            case .database(let text): return "Не удалось открыть файл сообщений: \(text)"
            }
        }
    }

    /// Тексты SMS банка из файла.
    static func messages(from url: URL) throws -> [String] {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        // Копируем во временную папку: файл может лежать в iCloud Drive, а SQLite нужен обычный путь.
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent("spent-import-\(UUID().uuidString)")
        let coordinator = NSFileCoordinator()
        var coordError: NSError?
        var copyError: Error?
        coordinator.coordinate(readingItemAt: url, options: [], error: &coordError) { readURL in
            do {
                try FileManager.default.copyItem(at: readURL, to: temp)
            } catch {
                copyError = error
            }
        }
        defer { try? FileManager.default.removeItem(at: temp) }
        if coordError != nil || copyError != nil { throw ImportError.unreadable }

        guard let handle = try? FileHandle(forReadingFrom: temp) else { throw ImportError.unreadable }
        let header = handle.readData(ofLength: 16)
        try? handle.close()

        if header.starts(with: Array("SQLite format 3".utf8)) {
            return try messagesFromDatabase(at: temp.path)
        }
        guard let data = try? Data(contentsOf: temp) else { throw ImportError.unreadable }
        let text = String(decoding: data, as: UTF8.self)
        return SMSParser.extractMessages(from: text)
    }

    /// База сообщений iPhone: таблица `message`, текст в `text` или (в новых iOS) в `attributedBody`.
    private static func messagesFromDatabase(at path: String) throws -> [String] {
        var db: OpaquePointer?
        guard sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let db else {
            throw ImportError.database("это не файл сообщений")
        }
        defer { sqlite3_close(db) }

        let sql = "SELECT text, attributedBody FROM message WHERE text LIKE '%OSTATOK%' OR (text IS NULL AND attributedBody IS NOT NULL)"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            let message = String(cString: sqlite3_errmsg(db))
            throw ImportError.database(message)
        }
        defer { sqlite3_finalize(statement) }

        var result: [String] = []
        let marker = Data("OSTATOK".utf8)
        while sqlite3_step(statement) == SQLITE_ROW {
            if let raw = sqlite3_column_text(statement, 0) {
                result.append(contentsOf: SMSParser.extractMessages(from: String(cString: raw)))
            } else if let blob = sqlite3_column_blob(statement, 1) {
                let count = Int(sqlite3_column_bytes(statement, 1))
                let data = Data(bytes: blob, count: count)
                guard data.range(of: marker) != nil else { continue }
                // В attributedBody текст лежит внутри служебных байтов — достаём его регуляркой.
                result.append(contentsOf: SMSParser.extractMessages(from: String(decoding: data, as: UTF8.self)))
            }
        }
        return result
    }
}
