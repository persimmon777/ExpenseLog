import SwiftUI

/// «Установить баланс карты»: если какие-то операции не попали в приложение.
struct BalanceSheet: View {
    @EnvironmentObject private var store: SpentStore
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var amountText = ""
    @FocusState private var focused: Bool

    private var amount: Decimal? {
        SMSParser.decimal(amountText.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "\u{00A0}", with: ""))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Остаток, BYN", text: $amountText)
                        .keyboardType(.decimalPad)
                        .font(theme.amountFont(.title2))
                        .focused($focused)
                } footer: {
                    Text("Посмотрите остаток в приложении банка и введите его здесь. Следующая SMS банка с остатком обновит его автоматически.")
                }
            }
            .themedBackground(theme)
            .navigationTitle("Баланс карты")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отменить") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        guard let amount else { return }
                        store.mutate { $0.setBalance(amount) }
                        dismiss()
                    }
                    .disabled(amount == nil)
                }
            }
            .onAppear {
                if let current = store.data.lastBalance {
                    amountText = NSDecimalNumber(decimal: current).stringValue.replacingOccurrences(of: ".", with: ",")
                }
                focused = true
            }
        }
        .presentationDetents([.medium])
    }
}
