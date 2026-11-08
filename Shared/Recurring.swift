import Foundation

// MARK: - Даты регулярных платежей

extension RecurringItem {

    /// Ближайшая дата платежа, не раньше дня `date` (сегодня тоже подходит).
    func nextDate(onOrAfter date: Date) -> Date {
        let cal = Fmt.calendar
        let today = cal.startOfDay(for: date)
        let first = cal.startOfDay(for: anchor)
        if first >= today { return first }

        switch period {
        case .weekly:
            let days = cal.dateComponents([.day], from: first, to: today).day ?? 0
            let rest = days % 7
            return cal.date(byAdding: .day, value: rest == 0 ? 0 : 7 - rest, to: today) ?? today
        case .monthly:
            let day = cal.component(.day, from: first)
            for offset in 0..<14 {
                guard let month = cal.date(byAdding: .month, value: offset, to: cal.dateInterval(of: .month, for: today)?.start ?? today),
                      let candidate = Self.date(in: month, day: day, calendar: cal) else { continue }
                if candidate >= today { return candidate }
            }
            return today
        case .yearly:
            let month = cal.component(.month, from: first)
            let day = cal.component(.day, from: first)
            let year = cal.component(.year, from: today)
            for y in year...(year + 2) {
                guard let monthStart = cal.date(from: DateComponents(year: y, month: month, day: 1)),
                      let candidate = Self.date(in: monthStart, day: day, calendar: cal) else { continue }
                if candidate >= today { return candidate }
            }
            return today
        }
    }

    /// Число в месяце; если такого нет (31-е в ноябре) — последний день месяца.
    private static func date(in month: Date, day: Int, calendar cal: Calendar) -> Date? {
        guard let start = cal.dateInterval(of: .month, for: month)?.start,
              let days = cal.range(of: .day, in: .month, for: start)?.count else { return nil }
        return cal.date(byAdding: .day, value: min(day, days) - 1, to: start)
    }

    /// Все даты платежа в полуинтервале [start, end).
    func dates(from start: Date, to end: Date) -> [Date] {
        var result: [Date] = []
        var current = nextDate(onOrAfter: start)
        let cal = Fmt.calendar
        while current < end && result.count < 60 {
            result.append(current)
            guard let next = cal.date(byAdding: .day, value: 1, to: current) else { break }
            current = nextDate(onOrAfter: next)
        }
        return result
    }

    /// Сколько в среднем в месяц.
    var monthlyEquivalent: Decimal {
        switch period {
        case .weekly: return amount * 52 / 12
        case .monthly: return amount
        case .yearly: return amount / 12
        }
    }

    /// «каждый месяц, 15-го» / «каждую неделю, среда» / «каждый год, 15 ноября».
    var scheduleText: String {
        switch period {
        case .weekly: return "каждую неделю, \(Fmt.weekdayName(anchor))"
        case .monthly: return "каждый месяц, \(Fmt.calendar.component(.day, from: anchor))-го"
        case .yearly: return "каждый год, \(Fmt.dayMonth(anchor))"
        }
    }
}

/// Регулярный платёж с ближайшей датой — для списка.
struct UpcomingRecurring: Identifiable {
    let item: RecurringItem
    let next: Date
    var id: UUID { item.id }
}

extension AppData {

    /// Активные, по ближайшей дате.
    func upcomingRecurring(now: Date = Date()) -> [UpcomingRecurring] {
        recurring
            .filter { $0.isActive }
            .map { UpcomingRecurring(item: $0, next: $0.nextDate(onOrAfter: now)) }
            .sorted { (a: UpcomingRecurring, b: UpcomingRecurring) in a.next < b.next }
    }

    /// Сколько ещё спишется / поступит до конца месяца (включая сегодня).
    func recurringLeftThisMonth(income: Bool, now: Date = Date()) -> Decimal {
        let cal = Fmt.calendar
        guard let end = cal.dateInterval(of: .month, for: now)?.end else { return 0 }
        return recurring
            .filter { $0.isActive && $0.isIncome == income }
            .reduce(Decimal(0)) { sum, item in
                sum + item.amount * Decimal(item.dates(from: now, to: end).count)
            }
    }

    /// Средняя сумма в месяц.
    func recurringMonthly(income: Bool) -> Decimal {
        recurring
            .filter { $0.isActive && $0.isIncome == income }
            .reduce(Decimal(0)) { $0 + $1.monthlyEquivalent }
    }

    mutating func saveRecurring(_ item: RecurringItem) {
        var item = item
        if item.isIncome { item.categoryID = nil }
        if let index = recurring.firstIndex(where: { $0.id == item.id }) {
            recurring[index] = item
        } else {
            recurring.append(item)
        }
    }

    mutating func deleteRecurring(_ id: UUID) {
        recurring.removeAll { $0.id == id }
    }
}
