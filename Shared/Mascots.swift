import SwiftUI

// MARK: - Персонажи-стикеры (Shared/Mascots.xcassets, нарезаны Tools/cut_mascots.py)

/// Персонаж: 6 картинок настроения «mascot-<id>-1…6».
struct Mascot: Identifiable, Hashable {
    let id: String
    let name: String
}

enum Mascots {
    static let all: [Mascot] = [
        Mascot(id: "persimmon", name: "Хурма"),
        Mascot(id: "husky", name: "Маламутик"),
        Mascot(id: "dachshund", name: "Таксик"),
        Mascot(id: "whitecat", name: "Анджелла"),
        Mascot(id: "ironman", name: "Железный"),
        Mascot(id: "girl", name: "Игорь"),
        Mascot(id: "boy", name: "Маратик"),
        Mascot(id: "tabby", name: "Котик"),
        Mascot(id: "washer", name: "Стиралка")
    ]

    /// «Каждый день новый» — по номеру дня, одинаково в приложении и виджете.
    static let randomID = "random"
    /// «Без персонажа».
    static let noneID = "none"

    /// Пороги настроения (доля потраченного от «Можно сегодня»): подписи для настроек.
    static let moodTitles = ["до 30%", "30–60%", "60–90%", "90–110%", "110–150%", "больше 150%"]

    static var selectedID: String {
        get { AppGroup.defaults.string(forKey: SharedSettings.Key.mascot) ?? randomID }
        set { AppGroup.defaults.set(newValue, forKey: SharedSettings.Key.mascot) }
    }

    /// Персонаж на этот день (nil — выключен).
    static func mascot(for date: Date = Date(), selected: String = selectedID) -> Mascot? {
        switch selected {
        case noneID:
            return nil
        case randomID:
            return daily(date)
        default:
            return all.first { $0.id == selected } ?? daily(date)
        }
    }

    static func daily(_ date: Date) -> Mascot {
        let day = Fmt.calendar.ordinality(of: .day, in: .era, for: date) ?? 0
        return all[day % all.count]
    }

    /// Настроение 1…6: до 30% — 1, 30–60 — 2, 60–90 — 3, 90–110 — 4, 110–150 — 5, больше 150 — 6.
    /// Без плана — спокойное (2).
    static func mood(spent: Decimal, allowance: Decimal?) -> Int {
        guard let allowance else { return 2 }
        guard allowance > 0 else { return spent > 0 ? 6 : 4 }
        let ratio = NSDecimalNumber(decimal: spent / allowance).doubleValue
        switch ratio {
        case ..<0.3: return 1
        case ..<0.6: return 2
        case ..<0.9: return 3
        case ...1.1: return 4
        case ...1.5: return 5
        default: return 6
        }
    }

    static func imageName(_ mascot: Mascot, mood: Int) -> String {
        "mascot-\(mascot.id)-\(min(max(mood, 1), 6))"
    }
}

extension AppData {
    /// Настроение персонажа сегодня: потрачено сегодня / «Можно сегодня».
    func mascotMood(now: Date = Date()) -> Int {
        // В бюджете на месяц — свободные деньги дня (`planStatus(.day)`), в плане на неделю — все траты дня.
        guard let status = planStatus(.day, containing: now) else { return Mascots.mood(spent: 0, allowance: nil) }
        return Mascots.mood(spent: status.spent, allowance: status.limit)
    }

    /// Имя картинки персонажа на сегодня или nil, если персонаж выключен.
    func mascotImageName(now: Date = Date()) -> String? {
        guard let mascot = Mascots.mascot(for: now) else { return nil }
        return Mascots.imageName(mascot, mood: mascotMood(now: now))
    }
}

/// Персонаж, вырезанный по контуру, с белой каймой наклейки.
struct MascotBadge: View {
    let imageName: String
    var size: CGFloat = 56

    var body: some View {
        Image(imageName)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: size, height: size)
            .shadow(color: .black.opacity(0.18), radius: 1.5, y: 1)
    }
}
