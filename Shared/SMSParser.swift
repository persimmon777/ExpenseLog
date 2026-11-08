import Foundation
import CryptoKit

/// Тип банковского SMS.
enum SMSType: String, Codable, CaseIterable {
    /// «OPLATA 22.60 BYN …» — оплата картой.
    case payment = "OPLATA"
    /// «POPOLNENIE KARTOCHKI 400.00 BYN …» — пополнение.
    case topUp = "POPOLNENIE"
    /// «NALICHNYE 10.00 BYN …» — снятие наличных.
    case cashWithdrawal = "NALICHNYE"

    /// Во что превращается SMS. Снятие наличных — перевод, не трата.
    var txKind: TxKind {
        switch self {
        case .payment: return .expense
        case .topUp: return .income
        case .cashWithdrawal: return .transfer
        }
    }
}

/// Результат разбора одного SMS.
struct ParsedSMS: Equatable {
    var type: SMSType
    var amount: Decimal
    var currency: String
    var cardLast4: String?
    var date: Date?
    /// Строка места целиком: «OMBSHOP.OZON.BY>MINSKIY R-N>BY».
    var placeRaw: String
    /// Короткое место: «OMBSHOP.OZON.BY».
    var place: String
    var mcc: String?
    var balance: Decimal?
    var fingerprint: String
}

/// Разбор SMS банка. Формат и примеры — в CLAUDE.md, раздел «Форматы SMS».
enum SMSParser {

    // MARK: Регулярные выражения

    private static let options: NSRegularExpression.Options = [.caseInsensitive, .dotMatchesLineSeparators]

    /// Начало сообщения: тип, сумма, валюта.
    private static let headRegex = make(#"^\s*(OPLATA|POPOLNENIE(?:\s+KARTOCHKI)?|NALICHNYE)\s+(\d+(?:[.,]\d{1,2})?)\s*([A-Z]{3})"#)
    /// Где начинается каждое сообщение — для разбиения пачки SMS.
    private static let startRegex = make(#"\b(OPLATA|POPOLNENIE|NALICHNYE)\b"#)
    private static let cardRegex = make(#"KARTA\s*#?\s*(\d{4})"#)
    private static let dateRegex = make(#"DATA\s+(\d{2}\.\d{2}\.\d{4})\s+(\d{2}:\d{2}(?::\d{2})?)"#)
    /// Место: всё между временем и «MCC:» / «OSTATOK» / концом текста.
    private static let placeRegex = make(#"DATA\s+\d{2}\.\d{2}\.\d{4}\s+\d{2}:\d{2}(?::\d{2})?\s+(.+?)\s*(?:MCC\s*:|OSTATOK\b|$)"#)
    private static let mccRegex = make(#"MCC\s*:\s*(\d{4})"#)
    private static let balanceRegex = make(#"OSTATOK\s+(-?\d+(?:[.,]\d{1,2})?)"#)
    /// Одно SMS целиком внутри «грязного» текста (файл сообщений, экспорт чата):
    /// от ключевого слова до «OSTATOK <сумма> <валюта>», не длиннее 400 символов.
    private static let messageRegex = make(#"(?:OPLATA|POPOLNENIE|NALICHNYE).{0,400}?OSTATOK\s+-?\d+(?:[.,]\d{1,2})?\s*[A-Z]{3}"#)

    private static func make(_ pattern: String) -> NSRegularExpression {
        // Шаблоны статические и проверены тестами — падение здесь означает ошибку в коде.
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: pattern, options: options)
    }

    // MARK: Публичное API

    /// Делит текст на отдельные SMS по ключевым словам OPLATA / POPOLNENIE / NALICHNYE.
    /// Текст до первого ключевого слова отбрасывается.
    static func split(_ text: String) -> [String] {
        let ns = text as NSString
        let matches = startRegex.matches(in: text, range: NSRange(location: 0, length: ns.length))
        guard !matches.isEmpty else {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? [] : [trimmed]
        }
        var parts: [String] = []
        for (i, match) in matches.enumerated() {
            let start = match.range.location
            let end = i + 1 < matches.count ? matches[i + 1].range.location : ns.length
            let part = ns.substring(with: NSRange(location: start, length: end - start))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !part.isEmpty { parts.append(part) }
        }
        return parts
    }

    /// Разбирает одно SMS. `nil` — если это не операция по карте.
    static func parse(_ message: String) -> ParsedSMS? {
        let text = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let head = firstMatch(headRegex, in: text, groups: 3) else { return nil }

        let keyword = head[0].uppercased()
        let type: SMSType
        if keyword.hasPrefix("OPLATA") {
            type = .payment
        } else if keyword.hasPrefix("POPOLNENIE") {
            type = .topUp
        } else {
            type = .cashWithdrawal
        }
        guard let amount = decimal(head[1]), amount > 0 else { return nil }

        let card = firstMatch(cardRegex, in: text, groups: 1)?[0]
        var date: Date?
        if let d = firstMatch(dateRegex, in: text, groups: 2) {
            date = parseDate(day: d[0], time: d[1])
        }
        let placeRaw = firstMatch(placeRegex, in: text, groups: 1)?[0]
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let mcc = firstMatch(mccRegex, in: text, groups: 1)?[0]
        let balance = firstMatch(balanceRegex, in: text, groups: 1).flatMap { decimal($0[0]) }

        return ParsedSMS(
            type: type,
            amount: amount,
            currency: head[2].uppercased(),
            cardLast4: card,
            date: date,
            placeRaw: placeRaw,
            place: placeRaw.isEmpty ? defaultPlace(for: type) : Merchant.shortName(placeRaw),
            mcc: mcc,
            balance: balance,
            fingerprint: fingerprint(text)
        )
    }

    /// Достаёт тексты SMS банка из любого текста: файла сообщений iPhone, экспорта чата, заметки.
    /// Мусор вокруг (служебные байты, даты, имена) отбрасывается.
    static func extractMessages(from text: String) -> [String] {
        let ns = text as NSString
        return messageRegex.matches(in: text, range: NSRange(location: 0, length: ns.length)).map {
            ns.substring(with: $0.range).trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    /// Разбирает пачку SMS.
    static func parseAll(_ text: String) -> [ParsedSMS] {
        split(text).compactMap(parse)
    }

    /// SHA-256 от нормализованного текста: верхний регистр, пробелы и переводы строк схлопнуты.
    static func fingerprint(_ text: String) -> String {
        let normalized = text.uppercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let digest = SHA256.hash(data: Data(normalized.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: Вспомогательное

    private static func defaultPlace(for type: SMSType) -> String {
        switch type {
        case .payment: return "Оплата картой"
        case .topUp: return "Пополнение"
        case .cashWithdrawal: return "Снятие наличных"
        }
    }

    /// Возвращает группы 1…n первого совпадения.
    private static func firstMatch(_ regex: NSRegularExpression, in text: String, groups: Int) -> [String]? {
        let ns = text as NSString
        guard let m = regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else { return nil }
        var result: [String] = []
        for i in 1...groups {
            let r = m.range(at: i)
            result.append(r.location == NSNotFound ? "" : ns.substring(with: r))
        }
        return result
    }

    /// «22.60» или «22,60» → Decimal.
    static func decimal(_ s: String) -> Decimal? {
        Decimal(string: s.replacingOccurrences(of: ",", with: "."), locale: Locale(identifier: "en_US_POSIX"))
    }

    private static let dateFormatterLong: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "dd.MM.yyyy HH:mm:ss"
        return f
    }()

    private static let dateFormatterShort: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "dd.MM.yyyy HH:mm"
        return f
    }()

    private static func parseDate(day: String, time: String) -> Date? {
        let s = "\(day) \(time)"
        return time.count > 5 ? dateFormatterLong.date(from: s) : dateFormatterShort.date(from: s)
    }
}
