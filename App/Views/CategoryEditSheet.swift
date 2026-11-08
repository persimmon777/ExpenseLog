import SwiftUI

/// Новая или существующая категория: название, эмодзи, цвет, лимит на месяц, удаление.
struct CategoryEditSheet: View {
    private let original: Category?
    private let onDelete: (() -> Void)?
    private let onSave: (Category) -> Void

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var emoji: String
    @State private var colorHex: String
    @State private var limitText: String
    @State private var confirmDelete = false

    private static let columns = [GridItem(.adaptive(minimum: 40), spacing: 12)]

    init(category: Category? = nil, onDelete: (() -> Void)? = nil, onSave: @escaping (Category) -> Void) {
        self.original = category
        self.onDelete = onDelete
        self.onSave = onSave
        _name = State(initialValue: category?.name ?? "")
        _emoji = State(initialValue: category?.emoji ?? "🏷️")
        _colorHex = State(initialValue: category?.colorHex ?? Category.palette[0])
        _limitText = State(initialValue: category?.monthlyLimit.map { NSDecimalNumber(decimal: $0).stringValue.replacingOccurrences(of: ".", with: ",") } ?? "")
    }

    private var limit: Decimal? {
        let clean = limitText.replacingOccurrences(of: " ", with: "")
        guard let value = SMSParser.decimal(clean), value > 0 else { return nil }
        return value
    }

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
                    LazyVGrid(columns: Self.columns, spacing: 12) {
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
                Section {
                    TextField("Без лимита", text: $limitText)
                        .keyboardType(.decimalPad)
                        .font(theme.amountFont(.body))
                } header: {
                    Text("Лимит на месяц, BYN")
                } footer: {
                    Text("Полоска станет жёлтой на 80% и красной на 100%. Оставьте пустым, если лимит не нужен.")
                }
                if original != nil, onDelete != nil {
                    Section {
                        Button("Удалить категорию", role: .destructive) { confirmDelete = true }
                    }
                }
            }
            .themedBackground(theme)
            .navigationTitle(original == nil ? "Новая категория" : "Категория")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отменить") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .confirmationDialog(
                "Удалить категорию «\(original?.name ?? "")»?",
                isPresented: $confirmDelete,
                titleVisibility: .visible
            ) {
                Button("Удалить", role: .destructive) {
                    onDelete?()
                    dismiss()
                }
                Button("Отменить", role: .cancel) {}
            } message: {
                Text("Траты из неё станут «Без категории», правила для неё удалятся.")
            }
        }
    }

    private func save() {
        var category = original ?? Category(name: "", emoji: "🏷️", colorHex: colorHex)
        category.name = name.trimmingCharacters(in: .whitespaces)
        category.emoji = emoji.isEmpty ? "🏷️" : emoji
        category.colorHex = colorHex
        category.monthlyLimit = limit
        onSave(category)
        dismiss()
    }
}
