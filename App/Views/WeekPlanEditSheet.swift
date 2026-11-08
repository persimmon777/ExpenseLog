import SwiftUI

/// План для одной недели: свой или по умолчанию.
struct WeekPlanEditSheet: View {
    let weekStart: Date

    @EnvironmentObject private var store: SpentStore
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var loaded = false
    @FocusState private var focused: Bool

    private var amount: Decimal? {
        guard let value = SMSParser.decimal(text.replacingOccurrences(of: " ", with: "")), value > 0 else { return nil }
        return value
    }

    var body: some View {
        let data = store.data
        let end = Fmt.calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
        let base = data.basePlan(forWeekStarting: weekStart)

        NavigationStack {
            Form {
                Section {
                    TextField("Без плана", text: $text)
                        .keyboardType(.decimalPad)
                        .font(theme.amountFont(.title3))
                        .focused($focused)
                    if let amount {
                        Text("≈ \(Fmt.money(amount / 7)) в день")
                            .font(.caption)
                            .foregroundStyle(theme.inkSoft)
                    }
                } header: {
                    Text("План на неделю, BYN")
                } footer: {
                    Text("По умолчанию: \(base.map { Fmt.money($0) } ?? "без плана").")
                }
                if data.isWeekPlanOverridden(weekStart) {
                    Section {
                        Button("Вернуть план по умолчанию") {
                            let start = weekStart
                            store.mutate { $0.setWeekPlan(nil, weekContaining: start) }
                            dismiss()
                        }
                    }
                }
            }
            .themedBackground(theme)
            .navigationTitle(Fmt.dayRange(weekStart, endExclusive: end))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отменить") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { save() }
                }
            }
            .onAppear {
                guard !loaded else { return }
                loaded = true
                text = data.weekPlan(containing: weekStart).map(WeeklyPlanView.text) ?? ""
                focused = true
            }
        }
        .presentationDetents([.medium])
    }

    private func save() {
        let start = weekStart
        let value = amount
        let base = store.data.basePlan(forWeekStarting: start)
        store.mutate { data in
            // Совпадает с планом по умолчанию — не храним как ручное изменение.
            data.setWeekPlan(value == base ? nil : (value ?? 0), weekContaining: start)
        }
        dismiss()
    }
}
