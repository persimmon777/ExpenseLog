import SwiftUI

/// Настройки → «Персонаж»: выбор стикера или «каждый день новый».
/// Настроение персонажа зависит от того, какая часть «Можно сегодня» уже потрачена.
struct MascotSettingsView: View {
    @EnvironmentObject private var store: SpentStore
    @Environment(\.theme) private var theme
    @AppStorage(SharedSettings.Key.mascot, store: AppGroup.defaults)
    private var selected: String = Mascots.randomID

    private let columns = [GridItem(.adaptive(minimum: 92), spacing: 12)]

    var body: some View {
        let today = Mascots.mascot(for: Date(), selected: selected)
        List {
            Section {
                HStack(spacing: 14) {
                    if let name = store.data.mascotImageName() {
                        MascotBadge(imageName: name, size: 72)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(today.map { "Сегодня: \($0.name)" } ?? "Персонаж выключен")
                            .font(.headline)
                            .foregroundStyle(theme.ink)
                        Text(today == nil
                             ? "Включите любого персонажа ниже."
                             : "Настроение: \(Mascots.moodTitles[store.data.mascotMood() - 1]) от «Можно сегодня».")
                            .font(.caption)
                            .foregroundStyle(theme.inkSoft)
                    }
                }
                .listRowBackground(theme.paper)
            }

            Section {
                option(title: "Каждый день новый", subtitle: "Персонаж меняется сам в полночь", id: Mascots.randomID)
                option(title: "Без персонажа", subtitle: nil, id: Mascots.noneID)
            }

            Section {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Mascots.all) { mascot in
                        Button {
                            choose(mascot.id)
                        } label: {
                            VStack(spacing: 6) {
                                MascotBadge(imageName: Mascots.imageName(mascot, mood: 1), size: 72)
                                Text(mascot.name)
                                    .font(.caption)
                                    .foregroundStyle(theme.ink)
                                    .lineLimit(1)
                            }
                            .padding(6)
                            .frame(maxWidth: .infinity)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(selected == mascot.id ? theme.accent : Color.clear, lineWidth: 3)
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 6)
                .listRowBackground(theme.paper)
            } header: {
                sectionHeader("Выбрать персонажа")
            }

            if let mascot = today {
                Section {
                    ForEach(1...6, id: \.self) { mood in
                        HStack(spacing: 12) {
                            MascotBadge(imageName: Mascots.imageName(mascot, mood: mood), size: 44)
                            Text("Потрачено \(Mascots.moodTitles[mood - 1])")
                                .foregroundStyle(theme.ink)
                            Spacer()
                            if mood == store.data.mascotMood() {
                                Text("сейчас")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(theme.accent)
                            }
                        }
                        .listRowBackground(theme.paper)
                    }
                } header: {
                    sectionHeader("Настроение")
                } footer: {
                    Text("Считается от «Можно сегодня»: сколько из дневной суммы уже потрачено. Если план трат не задан, персонаж спокойный.")
                        .foregroundStyle(theme.inkSoft)
                }
            }
        }
        .listStyle(.insetGrouped)
        .themedBackground(theme)
        .navigationTitle("Персонаж")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func option(title: String, subtitle: String?, id: String) -> some View {
        Button {
            choose(id)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundStyle(theme.ink)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(theme.inkSoft)
                    }
                }
                Spacer()
                if selected == id {
                    Image(systemName: "checkmark")
                        .foregroundStyle(theme.accent)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(theme.paper)
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(theme.inkSoft)
            .textCase(nil)
    }

    private func choose(_ id: String) {
        selected = id
        // Главная берёт персонажа из настроек — попросим её перерисоваться.
        store.objectWillChange.send()
    }
}
