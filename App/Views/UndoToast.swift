import SwiftUI

/// Плашка «Удалено · Отменить» внизу экрана.
struct UndoToast: View {
    @Environment(\.theme) private var theme
    let text: String
    let onUndo: () -> Void

    var body: some View {
        HStack {
            Text(text)
                .lineLimit(1)
            Spacer()
            Button("Отменить", action: onUndo)
                .fontWeight(.semibold)
        }
        .foregroundStyle(theme.paper)
        .tint(theme.paper)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(theme.ink, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}
