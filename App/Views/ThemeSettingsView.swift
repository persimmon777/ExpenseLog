import SwiftUI

/// «Оформление»: тема и одна из готовых палитр для неё.
struct ThemeSettingsView: View {
    @Environment(\.theme) private var theme
    @AppStorage(SharedSettings.Key.theme, store: AppGroup.defaults)
    private var themeRaw: String = ThemeID.receipt.rawValue
    @AppStorage(SharedSettings.Key.themePalettes, store: AppGroup.defaults)
    private var themePalettesRaw: String = ""

    private static let themeColumns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
    private static let paletteColumns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        let selectedTheme = ThemeID(rawValue: themeRaw) ?? .receipt
        let chosen = ThemePalettes.decode(themePalettesRaw)

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Тема")
                    .font(.headline)
                    .foregroundStyle(theme.ink)
                LazyVGrid(columns: Self.themeColumns, spacing: 10) {
                    ForEach(ThemeID.allCases) { id in
                        let preview = Theme.forID(id, palettes: chosen)
                        Button {
                            withAnimation { themeRaw = id.rawValue }
                        } label: {
                            ThemePreviewTile(preview: preview, title: id.title, isSelected: id == selectedTheme)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Text("Цвета")
                    .font(.headline)
                    .foregroundStyle(theme.ink)
                LazyVGrid(columns: Self.paletteColumns, spacing: 12) {
                    ForEach(selectedTheme.palettes) { palette in
                        let preview = Theme.forID(selectedTheme, palettes: [selectedTheme.rawValue: palette.id])
                        let isSelected = selectedTheme.palette(withID: chosen[selectedTheme.rawValue]).id == palette.id
                        Button {
                            choose(palette, for: selectedTheme)
                        } label: {
                            ThemePreviewTile(preview: preview, title: palette.name, isSelected: isSelected)
                        }
                        .buttonStyle(.plain)
                    }
                }
                Text("Сочетания подобраны так, чтобы текст и все элементы оставались хорошо видны. Цвета запоминаются отдельно для каждой темы.")
                    .font(.footnote)
                    .foregroundStyle(theme.inkSoft)
            }
            .padding(16)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("Оформление")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func choose(_ palette: ThemePalette, for id: ThemeID) {
        var dict = ThemePalettes.decode(themePalettesRaw)
        dict[id.rawValue] = palette.id
        withAnimation { themePalettesRaw = ThemePalettes.encode(dict) }
    }
}

/// Миниатюра темы/палитры: фон, карточка с «текстом», полоска основного цвета.
struct ThemePreviewTile: View {
    @Environment(\.theme) private var theme
    let preview: Theme
    let title: String
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(preview.background)
                VStack(alignment: .leading, spacing: 5) {
                    if preview.usesTiles {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(preview.accent)
                            .frame(height: 16)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Capsule().fill(preview.ink).frame(width: 34, height: 4)
                        Capsule().fill(preview.inkSoft).frame(width: 24, height: 3)
                        Capsule().fill(preview.accent).frame(height: 6)
                    }
                    .padding(7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(preview.paper, in: preview.cardShape)
                }
                .padding(8)
            }
            .frame(height: 86)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isSelected ? theme.accent : theme.rule, lineWidth: isSelected ? 3 : 1)
            )
            HStack(spacing: 4) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(theme.accent)
                }
                Text(title)
                    .font(.caption)
                    .foregroundStyle(theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
    }
}
