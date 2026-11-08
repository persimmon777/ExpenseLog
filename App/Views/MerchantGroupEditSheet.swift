import SwiftUI

/// Группа магазинов: название, что должно быть в названии из SMS, категория. С предпросмотром совпадений.
struct MerchantGroupEditSheet: View {
    private let original: MerchantGroup?

    @EnvironmentObject private var store: SpentStore
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var patternText: String
    @State private var categoryID: UUID?

    init(group: MerchantGroup?) {
        original = group
        _name = State(initialValue: group?.name ?? "")
        _patternText = State(initialValue: group?.patternText ?? "")
        _categoryID = State(initialValue: group?.categoryID)
    }

    private var pattern: String { Merchant.key(patternText) }

    var body: some View {
        let matches = store.data.merchantsMatching(patternText)

        NavigationStack {
            Form {
                Section {
                    TextField("Название, например «Соседи»", text: $name)
                    TextField("В SMS содержит, например SOSEDI", text: $patternText)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                } footer: {
                    Text("Достаточно части названия, как оно пишется в SMS латиницей. Цифры и знаки не важны.")
                }
                Section {
                    Picker("Категория", selection: $categoryID) {
                        Text("Не задана").tag(UUID?.none)
                        ForEach(store.data.categories) { c in
                            Text("\(c.emoji) \(c.name)").tag(UUID?.some(c.id))
                        }
                    }
                } footer: {
                    Text("Новые покупки группы сразу попадут в эту категорию. Неразобранные прошлые — тоже.")
                }
                if !pattern.isEmpty {
                    Section {
                        if matches.isEmpty {
                            Text("Пока ни одной покупки — группа подхватит будущие.")
                                .font(.footnote)
                                .foregroundStyle(theme.inkSoft)
                        }
                        ForEach(matches.prefix(15), id: \.self) { m in
                            Text(m)
                                .font(.footnote.monospaced())
                                .foregroundStyle(theme.ink)
                        }
                        if matches.count > 15 {
                            Text("и ещё \(matches.count - 15)")
                                .font(.footnote)
                                .foregroundStyle(theme.inkSoft)
                        }
                    } header: {
                        Text("Подходят из истории: \(matches.count)")
                    }
                }
            }
            .themedBackground(theme)
            .navigationTitle(original == nil ? "Новая группа" : "Группа")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отменить") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || pattern.isEmpty)
                }
            }
        }
    }

    private func save() {
        var group = original ?? MerchantGroup(name: "", pattern: "", patternText: "")
        group.name = name.trimmingCharacters(in: .whitespaces)
        group.patternText = patternText.trimmingCharacters(in: .whitespaces)
        group.pattern = pattern
        group.categoryID = categoryID
        let saved = group
        store.mutate { $0.saveGroup(saved) }
        dismiss()
    }
}
