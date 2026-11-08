import Foundation

/// Форматы и календарь приложения: ru_RU, неделя с понедельника.
enum Fmt {
    static let locale = Locale(identifier: "ru_RU")

    /// Григорианский календарь, ru_RU, первый день недели — понедельник.
    static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.locale = locale
        c.timeZone = .current
        c.firstWeekday = 2
        return c
    }()

    private static let number: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = locale
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        f.usesGroupingSeparator = true
        // Неразрывный пробел, чтобы сумма не переносилась на две строки.
        f.groupingSeparator = "\u{00A0}"
        f.decimalSeparator = ","
        return f
    }()

    /// «1 234,56 BYN».
    static func money(_ amount: Decimal, currency: String = "BYN") -> String {
        let n = number.string(from: NSDecimalNumber(decimal: amount)) ?? "\(amount)"
        return "\(n)\u{00A0}\(currency)"
    }

    /// «−22,60 BYN» / «+400,00 BYN» — знак по направлению денег.
    static func signedMoney(_ amount: Decimal, outgoing: Bool, currency: String = "BYN") -> String {
        (outgoing ? "−" : "+") + money(amount, currency: currency)
    }

    private static func formatter(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = locale
        f.calendar = calendar
        f.timeZone = .current
        f.dateFormat = format
        return f
    }

    private static let dayMonthFormatter = formatter("d MMMM")
    private static let monthYearFormatter = formatter("LLLL yyyy")
    private static let timeFormatter = formatter("HH:mm")

    /// «8 ноября».
    static func dayMonth(_ date: Date) -> String { dayMonthFormatter.string(from: date) }

    /// «Ноябрь 2026».
    static func monthYear(_ date: Date) -> String {
        let s = monthYearFormatter.string(from: date)
        return s.prefix(1).uppercased() + s.dropFirst()
    }

    /// «20:41».
    static func time(_ date: Date) -> String { timeFormatter.string(from: date) }

    /// Заголовок дня в истории: «Сегодня», «Вчера», «5 ноября».
    static func dayTitle(_ date: Date, now: Date = Date()) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return "Сегодня" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) { return "Вчера" }
        return dayMonth(date)
    }
}
