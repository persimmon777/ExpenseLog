import SwiftUI

extension View {
    /// Фон экрана из темы для списков и форм.
    func themedBackground(_ theme: Theme) -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(theme.background.ignoresSafeArea())
    }
}
