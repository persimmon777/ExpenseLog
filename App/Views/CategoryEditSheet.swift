import SwiftUI

/// Новая категория: название, эмодзи, цвет из палитры.
struct CategoryEditSheet: View {
    let onSave: (Category) -> Void

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var emoji = "🏷️"
    @State private var colorHex = Category.palette[0]

    private let columns = [GridItem(.adaptive(minimum: 40), spacing: 12)]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Название", text: $name)
                    TextField("Эмодзи", text: $emoji)
                        .onChange(of: emoji) { _, newValue in
                            if newValue.count > 1 { emoji = String(newValue.suffix(1)) }
                        }
                }
                Section("Цвет") {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(Category.palette, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Circle().strokeBorder(theme.ink, lineWidth: hex == colorHex ? 3 : 0)
                                )
                                .onTapGesture { colorHex = hex }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .themedBackground(theme)
            .navigationTitle("Новая категория")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отменить") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        let trimmed = name.trimmingCharacters(in: .whitespaces)
                        onSave(Category(name: trimmed, emoji: emoji.isEmpty ? "🏷️" : emoji, colorHex: colorHex))
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
