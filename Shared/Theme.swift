import SwiftUI

/// Оформление. Все цвета и формы во вью — только отсюда (через `@Environment(\.theme)`).
///
/// В каждой теме пользователь может заменить цвет фона и основной цвет (акцент) —
/// см. `Theme.forID(_:overrides:)` и `SharedSettings.Key.themeColors`.
struct Theme {
    let id: ThemeID
    /// Фон экрана («прилавок»). Может быть заменён пользователем.
    var background: Color
    /// Карточки.
    let paper: Color
    /// Основной текст.
    let ink: Color
    /// Вторичный текст.
    let inkSoft: Color
    /// Разделители.
    let rule: Color
    /// Основной цвет. Может быть заменён пользователем.
    var accent: Color
    /// Текст поверх основного цвета (на большой карточке «Сегодня» в «Лаванде»).
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
    /// Исходные цвета темы — для «Сбросить» в настройках.
    let defaultBackgroundHex: String
    let defaultAccentHex: String

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
        colorScheme: .light,
        defaultBackgroundHex: "E4E2DA",
        defaultAccentHex: "5B3CC4"
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
        colorScheme: .dark,
        defaultBackgroundHex: "0F1114",
        defaultAccentHex: "A08CFF"
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
        colorScheme: .light,
        defaultBackgroundHex: "F8F7FD",
        defaultAccentHex: "8B74F0"
    )

    /// Тема с учётом цветов, выбранных пользователем.
    /// `overrides` — словарь «<themeID>.background» / «<themeID>.accent» → hex.
    static func forID(_ id: ThemeID, overrides: [String: String] = [:]) -> Theme {
        var theme: Theme
        switch id {
        case .receipt: theme = .receipt
        case .card: theme = .card
        case .lavender: theme = .lavender
        }
        if let hex = overrides[ThemeColors.key(id, .background)] { theme.background = Color(hex: hex) }
        if let hex = overrides[ThemeColors.key(id, .accent)] { theme.accent = Color(hex: hex) }
        return theme
    }

    /// Текущая тема из общих настроек (для виджета и App Intent).
    static var current: Theme {
        forID(SharedSettings.themeID, overrides: ThemeColors.decode(AppGroup.defaults.string(forKey: SharedSettings.Key.themeColors) ?? ""))
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

/// Свои цвета тем: хранятся одной строкой JSON в `SharedSettings.Key.themeColors`.
enum ThemeColors {
    enum Slot: String {
        case background, accent
    }

    static func key(_ id: ThemeID, _ slot: Slot) -> String {
        "\(id.rawValue).\(slot.rawValue)"
    }

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
