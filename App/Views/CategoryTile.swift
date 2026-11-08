import SwiftUI

/// Плитка категории: эмодзи, название, цвет.
struct CategoryTile: View {
    @Environment(\.theme) private var theme
    let category: Category
    let isSelected: Bool
    let isSuggested: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(category.emoji).font(.title2)
                Text(category.name)
                    .font(.caption)
                    .foregroundStyle(theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(Color(hex: category.colorHex).opacity(isSelected ? 0.35 : 0.14),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(borderColor, style: StrokeStyle(lineWidth: 2, dash: isSuggested ? [5, 3] : []))
            )
        }
        .buttonStyle(.plain)
    }

    private var borderColor: Color {
        if isSelected { return Color(hex: category.colorHex) }
        if isSuggested { return theme.accent }
        return .clear
    }
}
