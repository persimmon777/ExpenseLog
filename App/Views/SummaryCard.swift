import SwiftUI

/// Сводка вверху главной. «Лаванда» — плитки, остальные темы — карточка-«чек».
struct SummaryCard: View {
    @Environment(\.theme) private var theme
    let onBalanceTap: () -> Void
    let onPlannedTap: () -> Void

    var body: some View {
        if theme.usesTiles {
            TilesSummary(onBalanceTap: onBalanceTap, onPlannedTap: onPlannedTap)
        } else {
            ReceiptSummary(onBalanceTap: onBalanceTap, onPlannedTap: onPlannedTap)
        }
    }
}

/// Карточка-«чек»: сегодня, за месяц, прогноз, планируется, остаток.
struct ReceiptSummary: View {
    @EnvironmentObject private var store: SpentStore
    @Environment(\.theme) private var theme
    /// Нажатие на «На карте» — установить баланс вручную.
    let onBalanceTap: () -> Void
    /// Нажатие на «Планируется» — открыть список покупок.
    let onPlannedTap: () -> Void

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
                Button(action: onPlannedTap) {
                    VStack(alignment: .leading, spacing: 2) {
                        AmountRow(title: "Планируется", value: Fmt.money(data.plannedTotal))
                        Text(plannedCaption(data))
                            .font(.caption2)
                            .foregroundStyle(theme.inkSoft)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                RuleLine()
                Button(action: onBalanceTap) {
                    VStack(alignment: .leading, spacing: 2) {
                        AmountRow(title: "На карте", value: data.lastBalance.map { Fmt.money($0) } ?? "указать")
                        Text(balanceCaption(data))
                            .font(.caption2)
                            .foregroundStyle(theme.inkSoft)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func plannedCaption(_ data: AppData) -> String {
        let count = data.shoppingToBuy.count
        guard count > 0 else { return "Список покупок пуст · нажмите, чтобы добавить" }
        return "\(Fmt.plural(count, "пункт", "пункта", "пунктов")) в списке покупок · нажмите, чтобы открыть"
    }

    private func balanceCaption(_ data: AppData) -> String {
        guard data.lastBalance != nil, let date = data.lastBalanceDate else {
            return "Нажмите, чтобы указать остаток на карте"
        }
        let source = data.balanceSetManually ? "указан вручную" : "из SMS"
        return "\(source), \(Fmt.dayTitle(date).lowercased()) в \(Fmt.time(date)) · нажмите, чтобы изменить"
    }
}
