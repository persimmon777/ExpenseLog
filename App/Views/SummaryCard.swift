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
                if let status = data.planStatus(.day) {
                    LimitBar(status: status)
                    Text(todayLine(status, carried: data.carriedIntoToday()))
                        .font(.caption2)
                        .foregroundStyle(status.level == .over ? theme.danger : theme.inkSoft)
                }
                RuleLine()
                AmountRow(title: "Неделя", value: planValue(data.planStatus(.week), spent: data.expenseTotal(in: .weekOfYear)))
                AmountRow(title: "За месяц", value: planValue(data.planStatus(.month), spent: data.expenseTotal(in: .month)))
                AmountRow(title: "Прогноз на месяц", value: Fmt.money(data.monthForecast()))
                Button(action: onPlannedTap) {
                    AmountRow(title: "Планируется", value: Fmt.money(data.plannedTotal))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                RuleLine()
                Button(action: onBalanceTap) {
                    VStack(alignment: .leading, spacing: 2) {
                        AmountRow(title: "На карте", value: data.lastBalance.map { Fmt.money($0) } ?? "указать")
                        if let caption = balanceCaption(data) {
                            Text(caption)
                                .font(.caption2)
                                .foregroundStyle(theme.inkSoft)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// «64,00 из 140,00 BYN» или просто сумма, если плана нет.
    private func planValue(_ status: LimitStatus?, spent: Decimal) -> String {
        guard let status else { return Fmt.money(spent) }
        return "\(Fmt.money(status.spent)) из \(Fmt.money(status.limit))"
    }

    /// «Можно сегодня ещё 7,60 из 25,00 BYN (+5,00 с прошлых дней)».
    private func todayLine(_ status: LimitStatus, carried: Decimal) -> String {
        let extra = carried > 0 ? " (+\(Fmt.money(carried)) с прошлых дней)" : ""
        if status.spent > status.limit {
            return "Перерасход \(Fmt.money(status.spent - status.limit)) · на сегодня было \(Fmt.money(status.limit))\(extra)"
        }
        return "Можно ещё \(Fmt.money(status.limit - status.spent)) из \(Fmt.money(status.limit))\(extra)"
    }

    /// «План 20,00 BYN в день · осталось 7,60 BYN».
    private func planLine(_ status: LimitStatus, unit: String) -> String {
        let base = "План \(Fmt.money(status.limit)) \(unit)"
        if status.spent > status.limit { return base + " · перерасход \(Fmt.money(status.spent - status.limit))" }
        return base + " · осталось \(Fmt.money(status.limit - status.spent))"
    }

    /// «из SMS, сегодня в 20:41» / «указан вручную, вчера в 09:10».
    private func balanceCaption(_ data: AppData) -> String? {
        guard data.lastBalance != nil, let date = data.lastBalanceDate else { return nil }
        let source = data.balanceSetManually ? "указан вручную" : "из SMS"
        return "\(source), \(Fmt.dayTitle(date).lowercased()) в \(Fmt.time(date))"
    }
}
