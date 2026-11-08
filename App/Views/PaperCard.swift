import SwiftUI

/// Карточка в стиле темы: «чек» с зубчатым краем или «карта» со скруглениями.
struct PaperCard<Content: View>: View {
    @Environment(\.theme) private var theme
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .padding(.bottom, theme.cardBottomInset)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(theme.ink)
            .background(theme.paper, in: theme.cardShape)
            .shadow(color: .black.opacity(theme.isReceipt ? 0.08 : 0), radius: 3, y: 1)
    }
}
