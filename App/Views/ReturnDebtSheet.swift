import SwiftUI

/// «Вернули»: можно выбрать пополнение, которым вернули долг, — оно не посчитается доходом.
struct ReturnDebtSheet: View {
    let debtID: UUID

    @EnvironmentObject private var store: SpentStore
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let data = store.data
        let candidates = data.debtReturnCandidates()

        NavigationStack {
            List {
                if let debt = data.debt(debtID) {
                    Section {
                        Button {
                            markReturned(transactionID: nil)
                        } label: {
                            Label("Вернули наличными или не на карту", systemImage: "checkmark.circle")
                        }
                        .listRowBackground(theme.paper)
                    } footer: {
                        Text("\(debt.person) · \(Fmt.money(debt.amount, currency: debt.currency))")
                            .foregroundStyle(theme.inkSoft)
                    }
                }

                Section {
                    if candidates.isEmpty {
                        Text("Пополнений на карту пока нет.")
                            .font(.footnote)
                            .foregroundStyle(theme.inkSoft)
                            .listRowBackground(theme.paper)
                    }
                    ForEach(candidates) { tx in
                        Button {
                            markReturned(transactionID: tx.id)
                        } label: {
                            TransactionRow(tx: tx, title: data.displayTitle(for: tx), category: nil)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(theme.paper)
                    }
                } header: {
                    Text("Или выберите пополнение, которым вернули")
                        .textCase(nil)
                } footer: {
                    Text("Выбранное пополнение станет «Возвратом долга» и не будет считаться доходом.")
                        .foregroundStyle(theme.inkSoft)
                }
            }
            .listStyle(.insetGrouped)
            .themedBackground(theme)
            .navigationTitle("Долг вернули")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отменить") { dismiss() }
                }
            }
        }
    }

    private func markReturned(transactionID: UUID?) {
        let id = debtID
        store.mutate { $0.setDebtReturned(id, returned: true, returnTransactionID: transactionID) }
        dismiss()
    }
}
