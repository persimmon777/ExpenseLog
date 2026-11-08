import SwiftUI

/// Форма «Это долг»: кому и когда вернут.
struct DebtFormSheet: View {
    let transactionID: UUID
    /// Вызывается после сохранения (закрыть и родительский лист).
    let onSaved: () -> Void

    @EnvironmentObject private var store: SpentStore
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var person = ""
    @State private var hasDueDate = true
    @State private var dueDate = Fmt.calendar.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Кому", text: $person)
                        .textInputAutocapitalization(.words)
                }
                Section {
                    Toggle("Дата возврата", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker("Вернуть до", selection: $dueDate, displayedComponents: .date)
                            .environment(\.locale, Fmt.locale)
                    }
                } footer: {
                    Text("В день возврата в 10:00 придёт напоминание (появится вместе с уведомлениями).")
                }
                Section {
                    TextField("Заметка", text: $note)
                }
            }
            .themedBackground(theme)
            .navigationTitle("Это долг")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отменить") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { save() }
                        .disabled(person.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        let name = person.trimmingCharacters(in: .whitespaces)
        let due: Date? = hasDueDate ? dueDate : nil
        let text = note.trimmingCharacters(in: .whitespaces)
        store.mutate { $0.makeDebt(fromTransaction: transactionID, person: name, dueDate: due, note: text.isEmpty ? nil : text) }
        dismiss()
        onSaved()
    }
}
