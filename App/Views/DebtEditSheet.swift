import SwiftUI

/// Новый долг (вручную, например наличными) или изменение существующего.
struct DebtEditSheet: View {
    private let original: Debt?

    @EnvironmentObject private var store: SpentStore
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var person: String
    @State private var amountText: String
    @State private var givenDate: Date
    @State private var hasDueDate: Bool
    @State private var dueDate: Date
    @State private var note: String

    init(debt: Debt?) {
        self.original = debt
        _person = State(initialValue: debt?.person ?? "")
        _amountText = State(initialValue: debt.map { NSDecimalNumber(decimal: $0.amount).stringValue.replacingOccurrences(of: ".", with: ",") } ?? "")
        _givenDate = State(initialValue: debt?.givenDate ?? Date())
        _hasDueDate = State(initialValue: debt == nil ? true : debt?.dueDate != nil)
        _dueDate = State(initialValue: debt?.dueDate ?? (Fmt.calendar.date(byAdding: .day, value: 7, to: Date()) ?? Date()))
        _note = State(initialValue: debt?.note ?? "")
    }

    /// Сумму долга, сделанного из операции по карте, не меняем — она из SMS.
    private var amountLocked: Bool { original?.givenTransactionID != nil }

    private var amount: Decimal? {
        guard let value = SMSParser.decimal(amountText.replacingOccurrences(of: " ", with: "")), value > 0 else { return nil }
        return value
    }

    private var canSave: Bool {
        !person.trimmingCharacters(in: .whitespaces).isEmpty && (amountLocked || amount != nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Кому", text: $person)
                        .textInputAutocapitalization(.words)
                    TextField("Сумма, BYN", text: $amountText)
                        .keyboardType(.decimalPad)
                        .font(theme.amountFont(.body))
                        .disabled(amountLocked)
                        .foregroundStyle(amountLocked ? theme.inkSoft : theme.ink)
                } footer: {
                    if amountLocked {
                        Text("Сумма взята из операции по карте.")
                    }
                }
                Section {
                    DatePicker("Когда дал", selection: $givenDate, displayedComponents: .date)
                        .environment(\.locale, Fmt.locale)
                    Toggle("Дата возврата", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker("Вернуть до", selection: $dueDate, displayedComponents: .date)
                            .environment(\.locale, Fmt.locale)
                    }
                }
                Section {
                    TextField("Заметка", text: $note)
                }
            }
            .themedBackground(theme)
            .navigationTitle(original == nil ? "Новый долг" : "Долг")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отменить") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { save() }
                        .disabled(!canSave)
                }
            }
        }
    }

    private func save() {
        let name = person.trimmingCharacters(in: .whitespaces)
        let text = note.trimmingCharacters(in: .whitespaces)
        if var debt = original {
            debt.person = name
            if let amount { debt.amount = amount }
            debt.givenDate = givenDate
            debt.dueDate = hasDueDate ? dueDate : nil
            debt.note = text.isEmpty ? nil : text
            let updated = debt
            store.mutate { $0.updateDebt(updated) }
        } else if let amount {
            let debt = Debt(person: name, amount: amount, givenDate: givenDate,
                            dueDate: hasDueDate ? dueDate : nil, note: text.isEmpty ? nil : text)
            store.mutate { $0.addDebt(debt) }
        }
        dismiss()
    }
}
