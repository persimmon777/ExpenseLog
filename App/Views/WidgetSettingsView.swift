import SwiftUI
import WidgetKit

/// Настройки → «Виджет»: до 3 строк виджета «Траты за сегодня» — что считать и за какой срок.
struct WidgetSettingsView: View {
    @EnvironmentObject private var store: SpentStore
    @Environment(\.theme) private var theme

    @State private var rows: [WidgetRowConfig] = WidgetRowConfig.saved

    var body: some View {
        let data = store.data
        let values = data.widgetRows(rows)
        List {
            Section {
                ForEach($rows) { $row in
                    VStack(alignment: .leading, spacing: 8) {
                        Picker("Что", selection: $row.source) {
                            Text(data.isMonthlyBudget ? "Свободные деньги" : "Весь план").tag(WidgetRowConfig.free)
                            if data.isMonthlyBudget {
                                ForEach(data.envelopeCategories) { c in
                                    Text("\(c.emoji) \(c.name)").tag(c.id.uuidString)
                                }
                            }
                        }
                        Picker("Срок", selection: $row.period) {
                            ForEach(WidgetRowConfig.Period.allCases) { period in
                                Text(period.title).tag(period)
                            }
                        }
                        .pickerStyle(.segmented)
                        if let value = values.first(where: { $0.id == row.id }) {
                            Text("Сейчас: \(value.title) — \(value.isOver ? "перерасход " : "")\(Fmt.money(abs(value.canSpend)))")
                                .font(.caption)
                                .foregroundStyle(value.isOver ? theme.danger : theme.inkSoft)
                        } else {
                            Text("Нет данных: задайте план трат" + (data.isMonthlyBudget ? " или выберите другой конверт" : ""))
                                .font(.caption)
                                .foregroundStyle(theme.inkSoft)
                        }
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(theme.paper)
                }
                .onDelete { offsets in
                    guard rows.count - offsets.count >= 1 else { return }
                    rows.remove(atOffsets: offsets)
                }
                if rows.count < WidgetRowConfig.maxRows {
                    Button {
                        rows.append(WidgetRowConfig())
                    } label: {
                        Label("Добавить строку", systemImage: "plus")
                    }
                    .listRowBackground(theme.paper)
                }
            } header: {
                Text("Строки виджета «Траты за сегодня»")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.inkSoft)
                    .textCase(nil)
            } footer: {
                Text(footer(data))
                    .foregroundStyle(theme.inkSoft)
            }
        }
        .listStyle(.insetGrouped)
        .themedBackground(theme)
        .navigationTitle("Виджет")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: rows) { _, newValue in
            WidgetRowConfig.saved = newValue
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    private func footer(_ data: AppData) -> String {
        var text = "До трёх строк: первая крупно, остальные под ней. «Неделя» — сколько можно до воскресенья. Проведите влево, чтобы убрать строку."
        if data.isMonthlyBudget && data.envelopeCategories.isEmpty {
            text += " Конверты появятся в списке, когда вы разложите бюджет: Настройки → «План трат» → «Структура бюджета»."
        }
        if !data.isMonthlyBudget {
            text += " Конверты доступны в режиме «Бюджет на месяц»."
        }
        return text
    }
}
