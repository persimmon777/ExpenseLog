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

    /// Что крупно вверху: сегодня, неделя или месяц (Настройки → «Крупно на главной»).
    @AppStorage(SharedSettings.Key.homePeriod, store: AppGroup.defaults)
    private var homePeriodRaw: String = AnalyticsPeriod.day.rawValue

    var body: some View {
        let data = store.data
        let main = AnalyticsPeriod(rawValue: homePeriodRaw) ?? .day
        let snapshot = data.monthlySnapshot()
        let hasEnvelopes = !(snapshot?.envelopes.isEmpty ?? true)
        PaperCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(Fmt.monthYear(Date()))
                            .font(.caption)
                            .foregroundStyle(theme.inkSoft)
                        AmountRow(title: Self.title(main), value: Fmt.money(data.expenseTotal(in: main.component)), emphasized: true)
                        if let status = data.planStatus(main) {
                            LimitBar(status: status)
                            Text((main == .day && hasEnvelopes ? "Свободные: " : "")
                                 + (main == .day ? todayLine(status, carried: data.carriedIntoToday()) : periodLine(status)))
                                .font(.caption2)
                                .foregroundStyle(status.level == .over ? theme.danger : theme.inkSoft)
                            if main == .day, let shortage = snapshot?.freeShortage {
                                Text("Свободных денег месяца не хватает на запланированное: −\(Fmt.money(shortage))")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(theme.danger)
                            }
                        }
                    }
                    if let mascot = data.mascotImageName() {
                        MascotBadge(imageName: mascot, size: 76)
                    }
                }
                if let snapshot, hasEnvelopes {
                    RuleLine()
                    EnvelopesView(snapshot: snapshot)
                }
                RuleLine()
                ForEach(AnalyticsPeriod.allCases.filter { $0 != main }) { period in
                    AmountRow(title: Self.title(period), value: planValue(data.planStatus(period), spent: data.expenseTotal(in: period.component)))
                }
                if let snapshot, snapshot.plannedTotal > 0 {
                    Text("В бюджете месяца ещё запланировано \(Fmt.money(snapshot.plannedTotal))")
                        .font(.caption2)
                        .foregroundStyle(theme.inkSoft)
                }
                AmountRow(title: "Прогноз на месяц", value: Fmt.money(data.monthForecast()))
                Button(action: onPlannedTap) {
                    VStack(alignment: .leading, spacing: 6) {
                        AmountRow(title: "Планируемые траты", value: "−" + Fmt.money(data.plannedExpenseTotal()))
                        AmountRow(title: "Планируемые поступления", value: "+" + Fmt.money(data.plannedIncomeTotal()))
                    }
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
        let extra: String
        if carried > 0 {
            extra = " (+\(Fmt.money(carried)) с прошлых дней)"
        } else if carried < 0 {
            extra = " (−\(Fmt.money(-carried)) за перерасход прошлых дней)"
        } else {
            extra = ""
        }
        if status.spent > status.limit {
            return "Перерасход \(Fmt.money(status.spent - status.limit)) · на сегодня было \(Fmt.money(status.limit))\(extra)"
        }
        return "Можно ещё \(Fmt.money(status.limit - status.spent)) из \(Fmt.money(status.limit))\(extra)"
    }

    /// «Сегодня» / «Неделя» / «За месяц».
    static func title(_ period: AnalyticsPeriod) -> String {
        switch period {
        case .day: return "Сегодня"
        case .week: return "Неделя"
        case .month: return "За месяц"
        }
    }

    /// «Можно ещё 40,00 из 140,00 BYN» / «Перерасход 5,00 · план 140,00 BYN».
    private func periodLine(_ status: LimitStatus) -> String {
        if status.spent > status.limit {
            return "Перерасход \(Fmt.money(status.spent - status.limit)) · план \(Fmt.money(status.limit))"
        }
        return "Можно ещё \(Fmt.money(status.limit - status.spent)) из \(Fmt.money(status.limit))"
    }

    /// «из SMS, сегодня в 20:41» / «указан вручную, вчера в 09:10».
    private func balanceCaption(_ data: AppData) -> String? {
        guard data.lastBalance != nil, let date = data.lastBalanceDate else { return nil }
        let source = data.balanceSetManually ? "указан вручную" : "из SMS"
        return "\(source), \(Fmt.dayTitle(date).lowercased()) в \(Fmt.time(date))"
    }
}
