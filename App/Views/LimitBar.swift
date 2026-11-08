import SwiftUI

/// Полоска лимита: зелёная → жёлтая с 80% → красная с 100%.
struct LimitBar: View {
    @Environment(\.theme) private var theme
    let status: LimitStatus

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(theme.rule)
                Capsule()
                    .fill(color)
                    .frame(width: geo.size.width * CGFloat(min(max(status.ratio, 0), 1)))
            }
        }
        .frame(height: 6)
    }

    private var color: Color {
        switch status.level {
        case .ok: return theme.positive
        case .warning: return theme.warning
        case .over: return theme.danger
        }
    }
}
