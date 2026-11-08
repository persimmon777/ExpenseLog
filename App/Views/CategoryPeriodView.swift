import SwiftUI

/// Операции одной категории за период (из гистограммы «Аналитики»).
struct CategoryPeriodView: View {
    @EnvironmentObject private var store: SpentStore
    @Environment(\.theme) private var theme

    let categoryID: UUID?
    let title: String
    let periodTitle: String
    let start: Date
    let end: Date

    var body: some View {
        let data = store.data
        let items = data.expenses(from: start, to: end, categoryID: categoryID)
        let total = items.reduce(Decimal(0)) { $0 + $1.amount }

        List {
            Section {
                ForEach(items) { tx in
                    TransactionRow(tx: tx, title: data.displayTitle(for: tx), category: data.category(tx.categoryID))
                        .listRowBackground(theme.paper)
                        .listRowSeparatorTint(theme.rule)
                }
            } header: {
                HStack {
                    Text(periodTitle)
                    Spacer()
                    Text(Fmt.money(total))
                        .font(theme.amountFont(.subheadline))
                        .foregroundStyle(theme.ink)
                }
                .textCase(nil)
            }
        }
        .listStyle(.insetGrouped)
        .themedBackground(theme)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
