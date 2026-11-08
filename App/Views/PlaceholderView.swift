import SwiftUI

/// Заглушка вкладки, которая будет сделана позже.
struct PlaceholderView: View {
    @Environment(\.theme) private var theme
    let title: String
    let text: String

    var body: some View {
        NavigationStack {
            VStack {
                PaperCard {
                    Text(text)
                        .foregroundStyle(theme.inkSoft)
                }
                Spacer()
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.background.ignoresSafeArea())
            .navigationTitle(title)
        }
    }
}
