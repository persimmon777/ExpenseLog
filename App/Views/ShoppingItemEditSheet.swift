import SwiftUI

/// Изменить пункт списка покупок.
struct ShoppingItemEditSheet: View {
    @EnvironmentObject private var store: SpentStore
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    private let item: ShoppingItem
    @State private var title: String
    @State private var priceText: String
    @State private var merchant: String

    init(item: ShoppingItem) {
        self.item = item
        _title = State(initialValue: item.title)
        _priceText = State(initialValue: item.price.map { NSDecimalNumber(decimal: $0).stringValue.replacingOccurrences(of: ".", with: ",") } ?? "")
        _merchant = State(initialValue: item.merchantName ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Что купить", text: $title)
                    TextField("Примерная цена, BYN", text: $priceText)
                        .keyboardType(.decimalPad)
                        .font(theme.amountFont(.body))
                }
                Section {
                    MerchantField(name: $merchant)
                } header: {
                    Text("Отметить само")
                } footer: {
                    Text("Укажите магазин — когда придёт оплата в нём на сумму около цены (±20%), пункт сам отметится купленным.")
                }
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
                        let trimmed = merchant.trimmingCharacters(in: .whitespaces)
                        updated.merchantKey = trimmed.merchantKeyOrNil
                        updated.merchantName = updated.merchantKey == nil ? nil : trimmed
                        store.mutate { $0.updateShoppingItem(updated) }
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
