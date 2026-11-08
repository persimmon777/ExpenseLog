import SwiftUI

/// Изменить пункт списка покупок.
struct ShoppingItemEditSheet: View {
    @EnvironmentObject private var store: SpentStore
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    private let item: ShoppingItem
    @State private var title: String
    @State private var priceText: String

    init(item: ShoppingItem) {
        self.item = item
        _title = State(initialValue: item.title)
        _priceText = State(initialValue: item.price.map { NSDecimalNumber(decimal: $0).stringValue.replacingOccurrences(of: ".", with: ",") } ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Что купить", text: $title)
                TextField("Примерная цена, BYN", text: $priceText)
                    .keyboardType(.decimalPad)
                    .font(theme.amountFont(.body))
            }
            .themedBackground(theme)
            .navigationTitle("Пункт списка")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отменить") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        var updated = item
                        updated.title = title.trimmingCharacters(in: .whitespaces)
                        updated.price = SMSParser.decimal(priceText.replacingOccurrences(of: " ", with: ""))
                        store.mutate { $0.updateShoppingItem(updated) }
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
