import SwiftUI

/// Карточка-«чек» вверху главной: сегодня, за месяц, остаток, прогноз.
struct SummaryCard: View {
    @EnvironmentObject private var store: SpentStore
    @Environment(\.theme) private var theme

    var body: some View {
        let data = store.data
        PaperCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(Fmt.monthYear(Date()))
                    .font(.caption)
                    .foregroundStyle(theme.inkSoft)
                AmountRow(title: "Сегодня", value: Fmt.money(data.expenseTotal(in: .day)), emphasized: true)
                RuleLine()
                AmountRow(title: "За месяц", value: Fmt.money(data.expenseTotal(in: .month)))
                AmountRow(title: "Прогноз на месяц", value: Fmt.money(data.monthForecast()))
                AmountRow(title: "На карте", value: data.lastBalance.map { Fmt.money($0) } ?? "—")
            }
        }
    }
}
