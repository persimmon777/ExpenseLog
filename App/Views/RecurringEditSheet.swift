import SwiftUI

/// Регулярный платёж или поступление: название, сумма, как часто, ближайшая дата, категория.
struct RecurringEditSheet: View {
    private let original: RecurringItem?

    @EnvironmentObject private var store: SpentStore
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var amountText: String
    @State private var isIncome: Bool
    @State private var period: RecurringItem.Period
    @State private var anchor: Date
    @State private var categoryID: UUID?
    @State private var isActive: Bool
    @State private var confirmDelete = false

    init(item: RecurringItem?) {
        original = item
        _title = State(initialValue: item?.title ?? "")
        _amountText = State(initialValue: item.map { NSDecimalNumber(decimal: $0.amount).stringValue.replacingOccurrences(of: ".", with: ",") } ?? "")
        _isIncome = State(initialValue: item?.isIncome ?? false)
        _period = State(initialValue: item?.period ?? .monthly)
        _anchor = State(initialValue: item.map { $0.nextDate(onOrAfter: Date()) } ?? Date())
        _categoryID = State(initialValue: item?.categoryID)
        _isActive = State(initialValue: item?.isActive ?? true)
    }

    private var amount: Decimal? {
        guard let value = SMSParser.decimal(amountText.replacingOccurrences(of: " ", with: "")), value > 0 else { return nil }
        return value
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Тип", selection: $isIncome) {
                        Text("Платёж").tag(false)
                        Text("Поступление").tag(true)
                    }
                    .pickerStyle(.segmented)
                    TextField(isIncome ? "Например: зарплата" : "Например: Яндекс Плюс", text: $title)
                    TextField("Сумма, BYN", text: $amountText)
                        .keyboardType(.decimalPad)
                        .font(theme.amountFont(.body))
                }
                Section {
                    Picker("Как часто", selection: $period) {
                        ForEach(RecurringItem.Period.allCases) { p in
                            Text(p.title).tag(p)
                        }
                    }
                    DatePicker(isIncome ? "Ближайшее поступление" : "Ближайшее списание", selection: $anchor, displayedComponents: .date)
                        .environment(\.locale, Fmt.locale)
                    if !isIncome {
                        Picker("Категория", selection: $categoryID) {
                            Text("Не выбрана").tag(UUID?.none)
                            ForEach(store.data.categories) { c in
                                Text("\(c.emoji) \(c.name)").tag(UUID?.some(c.id))
                            }
                        }
                    }
                } footer: {
                    Text(isIncome
                         ? "В день поступления в 10:00 придёт напоминание."
                         : "Накануне списания в 19:00 придёт напоминание. Сама трата появится, когда придёт SMS банка.")
                }
                if original != nil {
                    Section {
                        Toggle("Активен", isOn: $isActive)
                            .tint(theme.accent)
                        Button("Удалить", role: .destructive) { confirmDelete = true }
                    }
                }
            }
            .themedBackground(theme)
            .navigationTitle(original == nil ? (isIncome ? "Новое поступление" : "Новый платёж") : title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отменить") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || amount == nil)
                }
            }
            .confirmationDialog("Удалить «\(title)»?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Удалить", role: .destructive) {
                    if let id = original?.id {
                        store.mutate { $0.deleteRecurring(id) }
                    }
                    dismiss()
                }
                Button("Отменить", role: .cancel) {}
            }
        }
    }

    private func save() {
        guard let amount else { return }
        var item = original ?? RecurringItem(title: "", amount: amount, anchor: anchor)
        item.title = title.trimmingCharacters(in: .whitespaces)
        item.amount = amount
        item.isIncome = isIncome
        item.period = period
        item.anchor = anchor
        item.categoryID = isIncome ? nil : categoryID
        item.isActive = isActive
        let saved = item
        store.mutate { $0.saveRecurring(saved) }
        dismiss()
    }
}
