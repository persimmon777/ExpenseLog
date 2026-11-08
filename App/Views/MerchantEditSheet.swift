import SwiftUI

/// Магазин: своё название и категория «всегда относить».
struct MerchantEditSheet: View {
    /// Любая строка места этого магазина (из операции) — по ней берётся ключ.
    private let merchant: String

    @EnvironmentObject private var store: SpentStore
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var categoryID: UUID?
    @State private var loaded = false

    /// Из операции.
    init(merchant: String) {
        self.merchant = merchant
    }

    /// Из списка магазинов.
    init(merchantKey: String, originalName: String) {
        self.merchant = originalName.isEmpty ? merchantKey : originalName
    }

    private var key: String { Merchant.key(merchant) }
    private var original: String { Merchant.shortName(merchant) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(original, text: $name)
                        .textInputAutocapitalization(.sentences)
                } header: {
                    Text("Название")
                } footer: {
                    Text("В SMS: \(original). Оставьте пустым, чтобы показывать название из SMS.")
                }
                Section {
                    Picker("Категория", selection: $categoryID) {
                        Text("Не задана").tag(UUID?.none)
                        ForEach(store.data.categories) { c in
                            Text("\(c.emoji) \(c.name)").tag(UUID?.some(c.id))
                        }
                    }
                } header: {
                    Text("Всегда относить к категории")
                } footer: {
                    Text("Новые покупки в этом магазине сразу попадут в выбранную категорию. Неразобранные покупки тоже.")
                }
            }
            .themedBackground(theme)
            .navigationTitle("Магазин")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отменить") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { save() }
                }
            }
            .onAppear {
                guard !loaded else { return }
                loaded = true
                name = store.data.merchantNames[key] ?? ""
                categoryID = store.data.rules.first(where: { $0.pattern == key })?.categoryID
            }
        }
    }

    private func save() {
        let newName = name
        let newCategory = categoryID
        let source = merchant
        let oldCategory = store.data.rules.first(where: { $0.pattern == key })?.categoryID
        store.mutate { (data: inout AppData) -> Void in
            data.renameMerchant(source, to: newName)
            if newCategory != oldCategory {
                data.setRule(forMerchant: source, categoryID: newCategory)
            }
        }
        dismiss()
    }
}
