import SwiftUI
import UIKit

/// Настройки → «Иконка приложения»: монета или монета с персонажем.
/// Иконки — запасные (`AppIcon-<id>` в Assets.xcassets, Tools/make_mascot_icons.py),
/// превью для этого экрана — `icon-preview-<id>`.
struct AppIconSettingsView: View {
    @Environment(\.theme) private var theme
    @State private var current: String? = UIApplication.shared.alternateIconName
    @State private var errorText: String?

    private let columns = [GridItem(.adaptive(minimum: 90), spacing: 14)]

    var body: some View {
        List {
            Section {
                LazyVGrid(columns: columns, spacing: 14) {
                    tile(title: "Монета", preview: "icon-preview-coin", iconName: nil)
                    ForEach(Mascots.all) { mascot in
                        tile(title: mascot.name, preview: "icon-preview-\(mascot.id)", iconName: AppIconSettingsView.iconName(mascot))
                    }
                }
                .padding(.vertical, 6)
                .listRowBackground(theme.paper)
            } footer: {
                Text(errorText ?? "После выбора iPhone покажет сообщение «Вы изменили значок» — это нормально.")
                    .foregroundStyle(errorText == nil ? theme.inkSoft : theme.danger)
            }
        }
        .listStyle(.insetGrouped)
        .themedBackground(theme)
        .navigationTitle("Иконка приложения")
        .navigationBarTitleDisplayMode(.inline)
    }

    static func iconName(_ mascot: Mascot) -> String { "AppIcon-\(mascot.id)" }

    /// Подпись для строки в настройках.
    static var currentTitle: String {
        guard let name = UIApplication.shared.alternateIconName else { return "монета" }
        return Mascots.all.first { iconName($0) == name }?.name ?? "монета"
    }

    private func tile(title: String, preview: String, iconName: String?) -> some View {
        let selected = current == iconName
        return Button {
            choose(iconName)
        } label: {
            VStack(spacing: 6) {
                Image(preview)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(selected ? theme.accent : Color.clear, lineWidth: 3)
                            .padding(-4)
                    )
                Text(title)
                    .font(.caption)
                    .foregroundStyle(selected ? theme.accent : theme.ink)
                    .lineLimit(1)
            }
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func choose(_ iconName: String?) {
        guard UIApplication.shared.supportsAlternateIcons else {
            errorText = "Этот iPhone не разрешает менять иконку."
            return
        }
        guard iconName != current else { return }
        UIApplication.shared.setAlternateIconName(iconName) { error in
            DispatchQueue.main.async {
                if let error {
                    errorText = "Не получилось сменить иконку: \(error.localizedDescription)"
                } else {
                    errorText = nil
                    current = iconName
                }
            }
        }
    }
}
