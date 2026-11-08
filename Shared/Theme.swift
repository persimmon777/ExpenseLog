import SwiftUI

/// Оформление. Все цвета и формы во вью — только отсюда (через `@Environment(\.theme)`).
struct Theme {
    let id: ThemeID
    /// Фон экрана («прилавок»).
    let background: Color
    /// Карточки.
    let paper: Color
    /// Основной текст.
    let ink: Color
    /// Вторичный текст.
    let inkSoft: Color
    /// Разделители.
    let rule: Color
    let accent: Color
    let positive: Color
    let danger: Color
    /// Рваный зубчатый край снизу у карточек и пунктирные разделители («Чек»).
    let isReceipt: Bool
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
        positive: Color(hex: "2E7D4F"),
        danger: Color(hex: "C62828"),
        isReceipt: true,
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
        positive: Color(hex: "5FD08F"),
        danger: Color(hex: "FF6B6B"),
        isReceipt: false,
        cornerRadius: 18,
        amountDesign: .rounded,
        colorScheme: .dark
    )

    static func forID(_ id: ThemeID) -> Theme {
        switch id {
        case .receipt: return .receipt
        case .card: return .card
        }
    }

    /// Текущая тема из общих настроек (для виджета и App Intent).
    static var current: Theme { forID(SharedSettings.themeID) }

    /// Шрифт сумм.
    func amountFont(_ style: Font.TextStyle, weight: Font.Weight = .semibold) -> Font {
        .system(style, design: amountDesign).weight(weight)
    }

    /// Форма карточки: у «Чека» — зубчатый край снизу, у «Карты» — скругления.
    var cardShape: AnyShape {
        isReceipt ? AnyShape(ReceiptShape()) : AnyShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    /// Дополнительный отступ снизу карточки под зубцы.
    var cardBottomInset: CGFloat { isReceipt ? ReceiptShape.defaultToothHeight : 0 }
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
