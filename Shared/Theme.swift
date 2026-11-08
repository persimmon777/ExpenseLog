import SwiftUI

/// Оформление. Все цвета и формы во вью — только отсюда (через `@Environment(\.theme)`).
///
/// У каждой темы есть несколько готовых палитр (`ThemePalette`): фон, карточки и основной цвет
/// подобраны так, чтобы текст темы оставался читабельным. Выбор хранится в
/// `SharedSettings.Key.themePalettes` (см. `ThemePalettes`).
struct Theme {
    let id: ThemeID
    /// Фон экрана («прилавок»). Задаётся палитрой.
    var background: Color
    /// Карточки. Задаётся палитрой.
    var paper: Color
    /// Основной текст.
    let ink: Color
    /// Вторичный текст.
    let inkSoft: Color
    /// Разделители.
    let rule: Color
    /// Основной цвет. Задаётся палитрой.
    var accent: Color
    /// Текст поверх основного цвета (большая карточка «Сегодня» в «Лаванде», кнопки).
    let onAccent: Color
    let positive: Color
    let danger: Color
    /// Рваный зубчатый край снизу у карточек и пунктирные разделители («Чек»).
    let isReceipt: Bool
    /// Главная в виде плиток: большая карточка «Сегодня» + сетка 2×2 («Лаванда»).
    let usesTiles: Bool
    let cornerRadius: CGFloat
    /// Шрифт сумм.
    let amountDesign: Font.Design
    let colorScheme: ColorScheme

    static let receipt = Theme(
        id: .receipt,
        background: Color(hex: "E4E2DA"),
        paper: Color(hex: "FBFAF6"),
        ink: Color(hex: "1F1E1C"),
        inkSoft: Color(hex: "85827A"),
        rule: Color(hex: "CFCBC1"),
        accent: Color(hex: "5B3CC4"),
        onAccent: Color(hex: "FFFFFF"),
        positive: Color(hex: "2E7D4F"),
        danger: Color(hex: "C62828"),
        isReceipt: true,
        usesTiles: false,
        cornerRadius: 2,
        amountDesign: .monospaced,
        colorScheme: .light
    )

    static let card = Theme(
        id: .card,
        background: Color(hex: "0F1114"),
        paper: Color(hex: "1A1D22"),
        ink: Color(hex: "F1F0EC"),
        inkSoft: Color(hex: "8B8F97"),
        rule: Color(hex: "2C3037"),
        accent: Color(hex: "A08CFF"),
        onAccent: Color(hex: "0F1114"),
        positive: Color(hex: "5FD08F"),
        danger: Color(hex: "FF6B6B"),
        isReceipt: false,
        usesTiles: false,
        cornerRadius: 18,
        amountDesign: .rounded,
        colorScheme: .dark
    )

    static let lavender = Theme(
        id: .lavender,
        background: Color(hex: "F8F7FD"),
        paper: Color(hex: "EEEAFB"),
        ink: Color(hex: "1E1B2E"),
        inkSoft: Color(hex: "6E6A80"),
        rule: Color(hex: "DED8F3"),
        accent: Color(hex: "8B74F0"),
        onAccent: Color(hex: "FFFFFF"),
        positive: Color(hex: "2E9E5B"),
        danger: Color(hex: "E5484D"),
        isReceipt: false,
        usesTiles: true,
        cornerRadius: 20,
        amountDesign: .default,
        colorScheme: .light
    )

    /// Тема с выбранной палитрой. `palettes` — «themeID → id палитры».
    static func forID(_ id: ThemeID, palettes: [String: String] = [:]) -> Theme {
        var theme: Theme
        switch id {
        case .receipt: theme = .receipt
        case .card: theme = .card
        case .lavender: theme = .lavender
        }
        let palette = id.palette(withID: palettes[id.rawValue])
        theme.background = Color(hex: palette.background)
        theme.paper = Color(hex: palette.paper)
        theme.accent = Color(hex: palette.accent)
        return theme
    }

    /// Текущая тема из общих настроек (для виджета и App Intent).
    static var current: Theme {
        forID(SharedSettings.themeID, palettes: ThemePalettes.decode(AppGroup.defaults.string(forKey: SharedSettings.Key.themePalettes) ?? ""))
    }

    /// Шрифт сумм.
    func amountFont(_ style: Font.TextStyle, weight: Font.Weight = .semibold) -> Font {
        .system(style, design: amountDesign).weight(weight)
    }

    /// Форма карточки: у «Чека» — зубчатый край снизу, у остальных — скругления.
    var cardShape: AnyShape {
        isReceipt ? AnyShape(ReceiptShape()) : AnyShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    /// Дополнительный отступ снизу карточки под зубцы.
    var cardBottomInset: CGFloat { isReceipt ? ReceiptShape.defaultToothHeight : 0 }
}

// MARK: - Палитры

/// Готовое сочетание цветов для темы. Текст темы (`ink`, `inkSoft`) на нём читается.
struct ThemePalette: Identifiable {
    let id: String
    let name: String
    let background: String
    let paper: String
    let accent: String
}

extension ThemeID {
    /// 6 палитр для каждой темы; первая — исходная.
    var palettes: [ThemePalette] {
        switch self {
        case .receipt:
            return [
                ThemePalette(id: "thermal", name: "Термобумага", background: "E4E2DA", paper: "FBFAF6", accent: "5B3CC4"),
                ThemePalette(id: "mint", name: "Мята", background: "DCE8E1", paper: "F9FCFA", accent: "1F7A5A"),
                ThemePalette(id: "powder", name: "Пудра", background: "EADFDC", paper: "FDF9F8", accent: "B23A5B"),
                ThemePalette(id: "sky", name: "Небо", background: "DDE4EC", paper: "F9FBFD", accent: "2F5FA8"),
                ThemePalette(id: "sand", name: "Песок", background: "E9E0CF", paper: "FFFBF2", accent: "A0522D"),
                ThemePalette(id: "pencil", name: "Карандаш", background: "D9D9D9", paper: "FAFAFA", accent: "2B2B2B")
            ]
        case .card:
            return [
                ThemePalette(id: "graphite", name: "Графит", background: "0F1114", paper: "1A1D22", accent: "A08CFF"),
                ThemePalette(id: "night", name: "Ночь", background: "0B1220", paper: "152033", accent: "5FA8FF"),
                ThemePalette(id: "emerald", name: "Изумруд", background: "0C1412", paper: "16221F", accent: "4FD1A5"),
                ThemePalette(id: "cherry", name: "Вишня", background: "160E12", paper: "24171D", accent: "FF7AA2"),
                ThemePalette(id: "amber", name: "Янтарь", background: "14110C", paper: "221D15", accent: "FFB547"),
                ThemePalette(id: "ocean", name: "Океан", background: "0A1416", paper: "132225", accent: "3FD0D4")
            ]
        case .lavender:
            return [
                ThemePalette(id: "lavender", name: "Лаванда", background: "F8F7FD", paper: "EEEAFB", accent: "8B74F0"),
                ThemePalette(id: "mint", name: "Мята", background: "F5FAF8", paper: "E3F3EC", accent: "2A9A71"),
                ThemePalette(id: "peach", name: "Персик", background: "FFF8F4", paper: "FDE8DC", accent: "E8703F"),
                ThemePalette(id: "sky", name: "Небо", background: "F5F8FD", paper: "E3ECFA", accent: "4A7FE0"),
                ThemePalette(id: "rose", name: "Роза", background: "FDF6F8", paper: "F9E3EA", accent: "DB4F78"),
                ThemePalette(id: "lagoon", name: "Лагуна", background: "F4FBFB", paper: "DDF2F2", accent: "1A969A")
            ]
        }
    }

    /// Палитра по id; неизвестный id или `nil` — исходная.
    func palette(withID id: String?) -> ThemePalette {
        let all = palettes
        return all.first { $0.id == id } ?? all[0]
    }
}

/// Выбранные палитры тем: JSON «themeID → id палитры» в `SharedSettings.Key.themePalettes`.
enum ThemePalettes {
    static func decode(_ raw: String) -> [String: String] {
        guard let data = raw.data(using: .utf8),
              let dict = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
        return dict
    }

    static func encode(_ dict: [String: String]) -> String {
        guard let data = try? JSONEncoder().encode(dict) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }
}

/// Карточка-«чек»: прямоугольник с рваным зубчатым краем снизу.
struct ReceiptShape: Shape {
    static let defaultToothHeight: CGFloat = 6

    var toothWidth: CGFloat = 12
    var toothHeight: CGFloat = ReceiptShape.defaultToothHeight

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let bottom = rect.maxY - toothHeight
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: bottom))
        let count = max(1, Int((rect.width / toothWidth).rounded()))
        let w = rect.width / CGFloat(count)
        var x = rect.maxX
        for _ in 0..<count {
            p.addLine(to: CGPoint(x: x - w / 2, y: rect.maxY))
            x -= w
            p.addLine(to: CGPoint(x: x, y: bottom))
        }
        p.closeSubpath()
        return p
    }
}

/// Линия графика по значениям (0…max), слева направо. `closed` — с заливкой до низа.
struct SparklineShape: Shape {
    let values: [Double]
    var closed = false

    func path(in rect: CGRect) -> Path {
        var p = Path()
        guard values.count > 1 else { return p }
        let maxValue = max(values.max() ?? 0, 0.0001)
        let step = rect.width / CGFloat(values.count - 1)
        func point(_ i: Int) -> CGPoint {
            let y = rect.maxY - CGFloat(values[i] / maxValue) * rect.height
            return CGPoint(x: rect.minX + CGFloat(i) * step, y: y)
        }
        p.move(to: point(0))
        for i in 1..<values.count {
            p.addLine(to: point(i))
        }
        if closed {
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.closeSubpath()
        }
        return p
    }
}

private struct ThemeKey: EnvironmentKey {
    static let defaultValue: Theme = .receipt
}

extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

extension Color {
    /// `Color(hex: "5B3CC4")`.
    init(hex: String) {
        let clean = hex.trimmingCharacters(in: CharacterSet(charactersIn: "# "))
        let v = UInt64(clean, radix: 16) ?? 0
        self.init(
            .sRGB,
            red: Double((v >> 16) & 0xFF) / 255,
            green: Double((v >> 8) & 0xFF) / 255,
            blue: Double(v & 0xFF) / 255,
            opacity: 1
        )
    }
}
