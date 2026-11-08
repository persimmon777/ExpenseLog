import SwiftUI

/// Лист операции: выбор категории, тип, «учитывать в расчёте», заметка (CLAUDE.md, 5.1).
///
/// Два режима:
/// - из истории — после выбора категории лист остаётся открытым, закрывает «Готово»;
/// - из «Без категории» (`sortingQueue`) — после выбора сразу открывается следующая
///   неотсортированная покупка, чтобы быстро разнести всё в конце дня.
struct TransactionSheet: View {
    let sortingQueue: Bool

    @EnvironmentObject private var store: SpentStore
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var currentID: UUID
    @State private var alwaysUseRule = false
    @State private var note = ""
    @State private var noteLoaded = false
    @State private var showDebtForm = false
    @State private var showNewCategory = false
    @State private var showRename = false
    /// Подпись «Кафе ✓» после выбора в режиме разбора.
    @State private var lastChoice: String?

    private static let columns = [GridItem(.adaptive(minimum: 100), spacing: 10)]

    init(transactionID: UUID, sortingQueue: Bool = false) {
        self.sortingQueue = sortingQueue
        _currentID = State(initialValue: transactionID)
    }

    var body: some View {
        NavigationStack {
            Group {
                if let tx = store.data.transaction(currentID) {
                    content(tx)
                } else {
                    Text("Операция удалена")
                        .foregroundStyle(theme.inkSoft)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(theme.background.ignoresSafeArea())
            .navigationTitle(sortingQueue ? "Разбор покупок" : "Операция")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { close() }
                }
            }
        }
        .onAppear {
            guard !noteLoaded else { return }
            loadNote()
        }
        .sheet(isPresented: $showDebtForm) {
            DebtFormSheet(transactionID: currentID) { afterAction(closeOutsideQueue: true) }
                .environmentObject(store)
                .environment(\.theme, theme)
        }
        .sheet(isPresented: $showNewCategory) {
            CategoryEditSheet { category in
                store.mutate { $0.addCategory(category) }
            }
            .environment(\.theme, theme)
        }
        .sheet(isPresented: $showRename) {
            if let tx = store.data.transaction(currentID) {
                MerchantEditSheet(merchant: tx.merchant)
                    .environmentObject(store)
                    .environment(\.theme, theme)
            }
        }
    }

    // MARK: Содержимое

    private func content(_ tx: Transaction) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if sortingQueue {
                    queueStatus
                }

                header(tx)

                if tx.kind == .debtGiven || tx.kind == .debtReturn {
                    PaperCard {
                        Text("Эта операция связана с долгом. Изменить её можно в разделе «Долги».")
                            .foregroundStyle(theme.inkSoft)
                    }
                } else {
                    kindPicker(tx)
                    if tx.kind == .expense {
                        categoryGrid(tx)
                        excludeToggle(tx)
                    }
                    actionButtons(tx)
                }

                noteField
            }
            .padding(16)
        }
    }

    private var queueStatus: some View {
        let left = store.data.uncategorized.count
        return HStack {
            Text(left > 0 ? "Осталось без категории: \(left)" : "Все покупки разобраны")
                .font(.subheadline)
                .foregroundStyle(theme.inkSoft)
            Spacer()
            if let lastChoice {
                Text(lastChoice)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.positive)
            }
        }
    }

    private func header(_ tx: Transaction) -> some View {
        let title = store.data.displayTitle(for: tx)
        return PaperCard {
            VStack(alignment: .leading, spacing: 6) {
                Text(Fmt.signedMoney(tx.amount, outgoing: tx.kind.isOutgoing, currency: tx.currency))
                    .font(theme.amountFont(.largeTitle, weight: .bold))
                    .foregroundStyle(tx.kind.isOutgoing ? theme.ink : theme.positive)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(.headline)
                    Spacer(minLength: 8)
                    if tx.placeSubtitle == nil && !Merchant.key(tx.merchant).isEmpty {
                        Button("Переименовать") { showRename = true }
                            .font(.caption)
                    }
                }
                if let raw = tx.merchantRaw, raw != title {
                    Text(raw)
                        .font(.caption)
                        .foregroundStyle(theme.inkSoft)
                }
                RuleLine()
                    .padding(.vertical, 4)
                Text(detailsLine(tx))
                    .font(.caption)
                    .foregroundStyle(theme.inkSoft)
            }
        }
    }

    private func detailsLine(_ tx: Transaction) -> String {
        var parts = ["\(Fmt.dayTitle(tx.date)), \(Fmt.time(tx.date))"]
        if let card = tx.cardLast4 { parts.append("карта •\(card)") }
        if let mcc = tx.mcc { parts.append("MCC \(mcc)") }
        if tx.source == .manual { parts.append("добавлено вручную") }
        return parts.joined(separator: " · ")
    }

    private func kindPicker(_ tx: Transaction) -> some View {
        Picker("Тип", selection: Binding(
            get: { tx.kind },
            set: { newKind in store.mutate { $0.setKind(transactionID: tx.id, kind: newKind) } }
        )) {
            ForEach([TxKind.expense, .income, .transfer]) { kind in
                Text(kind.title).tag(kind)
            }
        }
        .pickerStyle(.segmented)
    }

    private func categoryGrid(_ tx: Transaction) -> some View {
        let data = store.data
        let suggestion = data.suggestedCategory(for: tx)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Категория").font(.headline)
                Spacer()
                if let suggestion, tx.categoryID == nil {
                    Text("Похоже на: \(suggestion.name)")
                        .font(.caption)
                        .foregroundStyle(theme.accent)
                }
            }
            LazyVGrid(columns: Self.columns, spacing: 10) {
                ForEach(data.categories) { category in
                    CategoryTile(
                        category: category,
                        isSelected: tx.categoryID == category.id,
                        isSuggested: suggestion?.id == category.id && tx.categoryID == nil
                    ) {
                        choose(category, for: tx)
                    }
                }
                Button {
                    showNewCategory = true
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "plus").font(.title3)
                        Text("Новая").font(.caption)
                    }
                    .foregroundStyle(theme.accent)
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .background(theme.paper, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            Toggle(isOn: $alwaysUseRule) {
                Text("Всегда относить «\(data.merchantName(tx.merchant))» к этой категории")
                    .font(.subheadline)
            }
            .tint(theme.accent)
        }
    }

    private func excludeToggle(_ tx: Transaction) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(isOn: Binding(
                get: { !tx.isExcluded },
                set: { counts in store.mutate { $0.setExcluded(transactionID: tx.id, excluded: !counts) } }
            )) {
                Text("Учитывать в расчёте трат")
                    .font(.subheadline)
            }
            .tint(theme.accent)
            Text("Выключите, если платили не за себя, например по просьбе родителей. Операция останется в истории, но не попадёт в итоги, категории и лимиты.")
                .font(.caption)
                .foregroundStyle(theme.inkSoft)
        }
    }

    private func actionButtons(_ tx: Transaction) -> some View {
        HStack(spacing: 10) {
            if tx.kind != .transfer {
                Button {
                    saveNote()
                    store.mutate { $0.setKind(transactionID: tx.id, kind: .transfer) }
                    lastChoice = "Перевод ✓"
                    afterAction(closeOutsideQueue: false)
                } label: {
                    Text("Это перевод").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            if tx.kind.isOutgoing {
                Button {
                    saveNote()
                    showDebtForm = true
                } label: {
                    Text("Это долг").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var noteField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Заметка").font(.headline)
            TextField("Например: подарок маме", text: $note, axis: .vertical)
                .lineLimit(1...4)
                .padding(12)
                .background(theme.paper, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    // MARK: Действия

    private func choose(_ category: Category, for tx: Transaction) {
        let rule = alwaysUseRule
        saveNote()
        store.mutate { $0.categorize(transactionID: tx.id, categoryID: category.id, createRule: rule) }
        lastChoice = "\(category.emoji) \(category.name) ✓"
        afterAction(closeOutsideQueue: false)
    }

    /// В режиме разбора — следующая неотсортированная покупка (или закрыть, если их нет).
    /// Вне разбора — остаёмся на операции, если не попросили закрыть.
    private func afterAction(closeOutsideQueue: Bool) {
        if sortingQueue {
            if let next = store.data.uncategorized.first(where: { $0.id != currentID }) {
                currentID = next.id
                alwaysUseRule = false
                loadNote()
            } else {
                dismiss()
            }
        } else if closeOutsideQueue {
            dismiss()
        }
    }

    private func loadNote() {
        note = store.data.transaction(currentID)?.note ?? ""
        noteLoaded = true
    }

    private func saveNote() {
        guard noteLoaded else { return }
        let current = store.data.transaction(currentID)?.note ?? ""
        guard note != current else { return }
        let text = note
        let id = currentID
        store.mutate { $0.setNote(transactionID: id, note: text) }
    }

    private func close() {
        saveNote()
        dismiss()
    }
}
