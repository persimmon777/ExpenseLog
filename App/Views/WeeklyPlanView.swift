import SwiftUI

/// «План трат»: режим «На неделю» (план по умолчанию и ручные недели; день = неделя / 7, месяц = сумма дней)
/// или «На месяц» (`MonthlyBudgetSections`: бюджет, свои месяцы, структура по конвертам).
struct WeeklyPlanView: View {
    @EnvironmentObject private var store: SpentStore
    @Environment(\.theme) private var theme

    @State private var baseText = ""
    @State private var loaded = false
    @State private var editingWeek: WeekRef?
    @FocusState private var baseFocused: Bool

    var body: some View {
        let data = store.data
        let weeks = weekStarts()

        Form {
            Section {
                Picker("Как считать", selection: Binding(
                    get: { data.budgetMode },
                    set: { mode in store.mutate { $0.setBudgetMode(mode) } }
                )) {
                    ForEach(BudgetMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            } footer: {
                Text(data.isMonthlyBudget
                     ? "Сумма на месяц делится на оставшиеся дни. Запланированные траты (список покупок, регулярные платежи) откладываются сразу. Часть бюджета можно разложить по конвертам-категориям."
                     : "План на неделю делится на оставшиеся дни недели.")
            }

            if data.isMonthlyBudget {
                MonthlyBudgetSections()
            } else {
                weeklySections(data: data, weeks: weeks)
            }
        }
        .themedBackground(theme)
        .navigationTitle("План трат")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Готово") {
                    baseFocused = false
                    // поле бюджета на месяц живёт в своём разделе — убираем клавиатуру для любого поля
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
        }
        .onAppear {
            guard !loaded else { return }
            loaded = true
            baseText = store.data.currentBasePlan.map(Self.text) ?? ""
        }
        .sheet(item: $editingWeek) { week in
            WeekPlanEditSheet(weekStart: week.start)
                .environmentObject(store)
                .environment(\.theme, theme)
                .preferredColorScheme(theme.colorScheme)
                .tint(theme.accent)
        }
    }

    // MARK: Части

    @ViewBuilder
    private func weeklySections(data: AppData, weeks: [Date]) -> some View {
            Section {
                HStack {
                    TextField("Без плана", text: $baseText)
                        .keyboardType(.decimalPad)
                        .font(theme.amountFont(.title3))
                        .focused($baseFocused)
                    Text("BYN в неделю")
                        .foregroundStyle(theme.inkSoft)
                }
                if let amount = parse(baseText) {
                    Text("≈ \(Fmt.money(amount / 7)) в день · ≈ \(Fmt.money(amount / 7 * 30)) в месяц")
                        .font(.caption)
                        .foregroundStyle(theme.inkSoft)
                }
                Button("Сохранить план по умолчанию") { saveBase() }
                    .disabled(parse(baseText) == data.currentBasePlan)
            } header: {
                Text("План на неделю по умолчанию")
            } footer: {
                Text("Действует с этой недели и дальше. Прошедшие недели не меняются. Оставьте пустым, чтобы убрать план.")
            }

            Section {
                ForEach(weeks, id: \.self) { start in
                    Button {
                        editingWeek = WeekRef(start: start)
                    } label: {
                        weekRow(start, data: data)
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("Недели")
            } footer: {
                Text("Нажмите на неделю, чтобы задать для неё свой план — например, если ждёте больших покупок.")
            }
    }

    private func weekRow(_ start: Date, data: AppData) -> some View {
        let cal = Fmt.calendar
        let end = cal.date(byAdding: .day, value: 7, to: start) ?? start
        let isCurrent = cal.isDate(start, equalTo: Date(), toGranularity: .weekOfYear)
        let isFuture = start > Date()
        let plan = data.weekPlan(containing: start)
        let spent = data.expenseTotal(from: start, to: end)
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(Fmt.dayRange(start, endExclusive: end) + (isCurrent ? " · эта неделя" : ""))
                    .foregroundStyle(theme.ink)
                    .fontWeight(isCurrent ? .semibold : .regular)
                Spacer()
                Text(plan.map { Fmt.money($0) } ?? "без плана")
                    .font(theme.amountFont(.subheadline))
                    .foregroundStyle(plan == nil ? theme.inkSoft : theme.ink)
            }
            HStack(spacing: 6) {
                if data.isWeekPlanOverridden(start) {
                    Text("изменено вручную")
                        .font(.caption2)
                        .foregroundStyle(theme.accent)
                }
                if !isFuture {
                    Text("потрачено \(Fmt.money(spent))")
                        .font(.caption)
                        .foregroundStyle(plan.map { spent > $0 } == true ? theme.danger : theme.inkSoft)
                }
            }
        }
        .contentShape(Rectangle())
    }

    /// 4 прошедшие недели, текущая и 8 следующих.
    private func weekStarts() -> [Date] {
        let cal = Fmt.calendar
        let current = store.data.weekStart(Date())
        return (-4...8).compactMap { cal.date(byAdding: .weekOfYear, value: $0, to: current) }
    }

    private func parse(_ text: String) -> Decimal? {
        guard let value = SMSParser.decimal(text.replacingOccurrences(of: " ", with: "")), value > 0 else { return nil }
        return value
    }

    static func text(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue.replacingOccurrences(of: ".", with: ",")
    }

    private func saveBase() {
        let amount = parse(baseText)
        store.mutate { $0.setBasePlan(amount) }
        baseFocused = false
    }
}

/// Неделя для листа изменения.
struct WeekRef: Identifiable {
    let start: Date
    var id: Date { start }
}
