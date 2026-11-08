import SwiftUI

/// Ручная операция: сумма, описание, дата, тип, категория.
struct ManualTransactionSheet: View {
    @EnvironmentObject private var store: SpentStore
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var amountText = ""
    @State private var title = ""
    @State private var date = Date()
    @State private var kind: TxKind = .expense
    @State private var categoryID: UUID?
    @FocusState private var amountFocused: Bool

    private var amount: Decimal? {
        guard let value = SMSParser.decimal(amountText.trimmingCharacters(in: .whitespaces)), value > 0 else { return nil }
        return value
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Сумма, BYN", text: $amountText)
                        .keyboardType(.decimalPad)
                        .font(theme.amountFont(.title2))
                        .focused($amountFocused)
                    TextField(kind == .expense ? "Что купили" : "Описание", text: $title)
                }
                Section {
                    Picker("Тип", selection: $kind) {
                        ForEach([TxKind.expense, .income, .transfer]) { k in
                            Text(k.title).tag(k)
                        }
                    }
                    .pickerStyle(.segmented)
                    if kind == .expense {
                        Picker("Категория", selection: $categoryID) {
                            Text("Без категории").tag(UUID?.none)
                            ForEach(store.data.categories) { c in
                                Text("\(c.emoji) \(c.name)").tag(UUID?.some(c.id))
                            }
                        }
                    }
                    DatePicker("Дата", selection: $date, displayedComponents: [.date, .hourAndMinute])
                        .environment(\.locale, Fmt.locale)
                }
            }
            .themedBackground(theme)
            .navigationTitle("Новая операция")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отменить") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { save() }
                        .disabled(amount == nil)
                }
            }
            .onAppear { amountFocused = true }
        }
    }

    private func save() {
        guard let amount else { return }
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        let name = trimmed.isEmpty ? (kind == .expense ? "Покупка" : kind.title) : trimmed
        let tx = Transaction(
            amount: amount,
            merchant: name,
            date: date,
            kind: kind,
            categoryID: kind == .expense ? categoryID : nil,
            source: .manual
        )
        store.mutate { $0.addManual(tx) }
        dismiss()
    }
}
