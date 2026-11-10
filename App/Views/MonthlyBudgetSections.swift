import SwiftUI

/// Разделы «Плана трат» в режиме «На месяц»: бюджет по умолчанию, месяцы со своей суммой, структура по конвертам.
struct MonthlyBudgetSections: View {
    @EnvironmentObject private var store: SpentStore
    @Environment(\.theme) private var theme

    @State private var baseText = ""
    @State private var loaded = false
    @State private var editingMonth: MonthRef?
    @FocusState private var focused: Bool

    var body: some View {
        let data = store.data
        Group {
            Section {
                HStack {
                    TextField("Без бюджета", text: $baseText)
                        .keyboardType(.decimalPad)
                        .font(theme.amountFont(.title3))
                        .focused($focused)
                    Text("BYN в месяц")
                        .foregroundStyle(theme.inkSoft)
                }
                if let amount = MonthlyBudgetSections.parse(baseText) {
                    Text("≈ \(Fmt.money(amount / 30)) в день")
                        .font(.caption)
                        .foregroundStyle(theme.inkSoft)
                }
                Button("Сохранить бюджет по умолчанию") {
                    let amount = MonthlyBudgetSections.parse(baseText)
                    store.mutate { $0.setBaseBudget(amount) }
                    focused = false
                }
                .disabled(MonthlyBudgetSections.parse(baseText) == data.currentBaseBudget)
            } header: {
                Text("Бюджет на месяц по умолчанию")
            } footer: {
                Text("Действует с этого месяца и дальше. Прошедшие месяцы не меняются. Оставьте пустым, чтобы убрать бюджет.")
            }

            Section {
                NavigationLink {
                    BudgetStructureView()
                } label: {
                    LabeledContent("Структура бюджета", value: structureSummary(data))
                }
            } footer: {
                Text("Разложите часть бюджета по конвертам-категориям, например «Еда» 150 и «Развлечения» 150. Остальное — свободные деньги, из них считается «Можно сегодня».")
            }

            Section {
                ForEach(months(), id: \.self) { start in
                    Button {
                        editingMonth = MonthRef(start: start)
                    } label: {
                        monthRow(start, data: data)
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("Месяцы")
            } footer: {
                Text("Нажмите на месяц, чтобы задать для него свою сумму — например, в декабре побольше на подарки.")
            }
            // Модификаторы на Group применились бы к каждому разделу — вешаем их на один.
            .onAppear {
                guard !loaded else { return }
                loaded = true
                baseText = store.data.currentBaseBudget.map(WeeklyPlanView.text) ?? ""
            }
            .sheet(item: $editingMonth) { month in
            MonthBudgetEditSheet(monthStart: month.start)
                .environmentObject(store)
                .environment(\.theme, theme)
                .preferredColorScheme(theme.colorScheme)
                .tint(theme.accent)
            }
        }
    }

    private func structureSummary(_ data: AppData) -> String {
        let envelopes = data.envelopeCategories
        guard !envelopes.isEmpty else { return "без конвертов" }
        return Fmt.plural(envelopes.count, "конверт", "конверта", "конвертов")
    }

    private func monthRow(_ start: Date, data: AppData) -> some View {
        let cal = Fmt.calendar
        let end = cal.date(byAdding: .month, value: 1, to: start) ?? start
        let isCurrent = cal.isDate(start, equalTo: Date(), toGranularity: .month)
        let budget = data.monthBudget(containing: start)
        let spent = data.expenseTotal(from: start, to: end)
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(Fmt.monthYear(start) + (isCurrent ? " · этот месяц" : ""))
                    .foregroundStyle(theme.ink)
                    .fontWeight(isCurrent ? .semibold : .regular)
                Spacer()
                Text(budget.map { Fmt.money($0) } ?? "без бюджета")
                    .font(theme.amountFont(.subheadline))
                    .foregroundStyle(budget == nil ? theme.inkSoft : theme.ink)
            }
            HStack(spacing: 6) {
                if data.isMonthBudgetOverridden(start) {
                    Text("изменено вручную")
                        .font(.caption2)
                        .foregroundStyle(theme.accent)
                }
                if start <= Date() {
                    Text("потрачено \(Fmt.money(spent))")
                        .font(.caption)
                        .foregroundStyle(budget.map { spent > $0 } == true ? theme.danger : theme.inkSoft)
                }
            }
        }
        .contentShape(Rectangle())
    }

    /// 2 прошедших месяца, текущий и 6 следующих.
    private func months() -> [Date] {
        let current = store.data.monthStart(Date())
        return (-2...6).compactMap { Fmt.calendar.date(byAdding: .month, value: $0, to: current) }
    }

    static func parse(_ text: String) -> Decimal? {
        guard let value = SMSParser.decimal(text.replacingOccurrences(of: " ", with: "")), value > 0 else { return nil }
        return value
    }
}

/// Месяц для листа изменения.
struct MonthRef: Identifiable {
    let start: Date
    var id: Date { start }
}

/// Бюджет одного месяца: свой или по умолчанию.
struct MonthBudgetEditSheet: View {
    let monthStart: Date

    @EnvironmentObject private var store: SpentStore
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var loaded = false
    @FocusState private var focused: Bool

    var body: some View {
        let data = store.data
        let base = data.baseBudget(forMonthStarting: monthStart)
        NavigationStack {
            Form {
                Section {
                    TextField("Без бюджета", text: $text)
                        .keyboardType(.decimalPad)
                        .font(theme.amountFont(.title3))
                        .focused($focused)
                } header: {
                    Text("Бюджет на месяц, BYN")
                } footer: {
                    Text("По умолчанию: \(base.map { Fmt.money($0) } ?? "без бюджета").")
                }
                if data.isMonthBudgetOverridden(monthStart) {
                    Section {
                        Button("Вернуть бюджет по умолчанию") {
                            let start = monthStart
                            store.mutate { $0.setMonthBudget(nil, monthContaining: start) }
                            dismiss()
                        }
                    }
                }
            }
            .themedBackground(theme)
            .navigationTitle(Fmt.monthYear(monthStart))
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
                text = data.monthBudget(containing: monthStart).map(WeeklyPlanView.text) ?? ""
                focused = true
            }
        }
        .presentationDetents([.medium])
    }

    private func save() {
        let start = monthStart
        let value = MonthlyBudgetSections.parse(text)
        let base = store.data.baseBudget(forMonthStarting: start)
        store.mutate { data in
            // Совпадает с бюджетом по умолчанию — не храним как ручное изменение.
            data.setMonthBudget(value == base ? nil : (value ?? 0), monthContaining: start)
        }
        dismiss()
    }
}
