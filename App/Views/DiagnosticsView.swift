import SwiftUI
import UIKit

/// ВРЕМЕННЫЙ экран: проверка установки, App Group и тем.
/// Заменяется вкладками из CLAUDE.md, раздел «Экраны».
struct DiagnosticsView: View {
    @EnvironmentObject private var store: SpentStore
    @Environment(\.theme) private var theme
    @AppStorage(SharedSettings.Key.theme, store: AppGroup.defaults)
    private var themeRaw: String = ThemeID.receipt.rawValue
    @State private var lastResult: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    summaryCard
                    stateCard
                    themeCard
                    recentCard
                }
                .padding(16)
            }
            .background(theme.background.ignoresSafeArea())
            .navigationTitle("Spent")
            .toolbarBackground(theme.background, for: .navigationBar)
        }
    }

    // MARK: Карточки

    private var summaryCard: some View {
        let data = store.data
        return PaperCard {
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

    private var stateCard: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Состояние").font(.headline)
                AmountRow(title: "Общая папка", value: AppGroup.isShared ? "работает" : "не найдена")
                Text(AppGroup.resolvedID ?? "—")
                    .font(.caption2)
                    .foregroundStyle(theme.inkSoft)
                RuleLine()
                AmountRow(title: "Операций", value: "\(store.data.transactions.count)")
                AmountRow(title: "Без категории", value: "\(store.data.uncategorized.count)")
                Button("Добавить SMS из буфера") { pasteSMS() }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 4)
                if let lastResult {
                    Text(lastResult)
                        .font(.footnote)
                        .foregroundStyle(theme.inkSoft)
                }
            }
        }
    }

    private var themeCard: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Тема").font(.headline)
                Picker("Тема", selection: $themeRaw) {
                    ForEach(ThemeID.allCases) { id in
                        Text(id.title).tag(id.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                HStack(spacing: 8) {
                    swatch(theme.accent)
                    swatch(theme.positive)
                    swatch(theme.danger)
                    swatch(theme.inkSoft)
                }
            }
        }
    }

    private var recentCard: some View {
        let recent = Array(store.data.transactions.sorted { $0.date > $1.date }.prefix(20))
        return PaperCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Последние операции").font(.headline)
                if recent.isEmpty {
                    Text("Пока пусто. Скопируйте SMS банка и нажмите «Добавить SMS из буфера».")
                        .font(.footnote)
                        .foregroundStyle(theme.inkSoft)
                }
                ForEach(recent) { tx in
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tx.kind == .expense ? tx.merchant : tx.kind.title)
                                .lineLimit(1)
                            Text("\(Fmt.dayTitle(tx.date)), \(Fmt.time(tx.date))")
                                .font(.caption)
                                .foregroundStyle(theme.inkSoft)
                        }
                        Spacer(minLength: 12)
                        Text(Fmt.signedMoney(tx.amount, outgoing: tx.kind.isOutgoing, currency: tx.currency))
                            .font(theme.amountFont(.body))
                            .foregroundStyle(tx.kind.isOutgoing ? theme.ink : theme.positive)
                    }
                }
            }
        }
    }

    private func swatch(_ color: Color) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(color)
            .frame(width: 28, height: 28)
    }

    // MARK: Действия

    private func pasteSMS() {
        let text = UIPasteboard.general.string ?? ""
        let r = store.mutate { $0.ingest(smsText: text) }
        lastResult = "Добавлено \(r.added.count), дублей \(r.duplicates), ранее удалено \(r.previouslyDeleted), не распознано \(r.unrecognized)"
    }
}
