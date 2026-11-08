import SwiftUI

/// Разделитель: в «Чеке» — пунктир, в «Карте» — тонкая линия.
struct RuleLine: View {
    @Environment(\.theme) private var theme

    var body: some View {
        HorizontalLine()
            .stroke(theme.rule, style: StrokeStyle(lineWidth: 1, dash: theme.isReceipt ? [4, 3] : []))
            .frame(height: 1)
    }
}

private struct HorizontalLine: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return p
    }
}
