import SwiftUI

/// Лист операции: выбор категории, тип, заметка (CLAUDE.md, 5.1).
struct TransactionSheet: View {
    let transactionID: UUID

    @EnvironmentObject private var store: SpentStore
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var alwaysUseRule = false
    @State private var note = ""
    @State private var noteLoaded = false
    @State private var showDebtForm = false
    @State private var showNewCategory = false

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 10)]

    var body: some View {
        NavigationStack {
            Group {
                if let tx = store.data.transaction(transactionID) {
                    content(tx)
                } else {
                    Text("Операция удалена")
                        .foregroundStyle(theme.inkSoft)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(theme.background.ignoresSafeArea())
            .navigationTitle("Операция")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { close() }
                }
            }
        }
        .onAppear {
            guard !noteLoaded else { return }
            note = store.data.transaction(transactionID)?.note ?? ""
            noteLoaded = true
        }
        .sheet(isPresented: $showDebtForm) {
            DebtFormSheet(transactionID: transactionID) { dismiss() }
                .environmentObject(store)
                .environment(\.theme, theme)
        }
        .sheet(isPresented: $showNewCategory) {
            CategoryEditSheet { category in
                store.mutate { $0.addCategory(category) }
            }
            .environment(\.theme, theme)
        }
    }

    // MARK: Содержимое

    private func content(_ tx: Transaction) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
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
                    }
                    actionButtons(tx)
                }

                noteField
            }
            .padding(16)
        }
    }

    private func header(_ tx: Transaction) -> some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 6) {
                Text(Fmt.signedMoney(tx.amount, outgoing: tx.kind.isOutgoing, currency: tx.currency))
                    .font(theme.amountFont(.largeTitle, weight: .bold))
                    .foregroundStyle(tx.kind.isOutgoing ? theme.ink : theme.positive)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(tx.title)
                    .font(.headline)
                if let raw = tx.merchantRaw, raw != tx.title {
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
            LazyVGrid(columns: columns, spacing: 10) {
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
                Text("Всегда относить «\(Merchant.shortName(tx.merchant))» к этой категории")
                    .font(.subheadline)
            }
            .tint(theme.accent)
        }
    }

    private func actionButtons(_ tx: Transaction) -> some View {
        HStack(spacing: 10) {
            if tx.kind != .transfer {
                Button {
                    store.mutate { $0.setKind(transactionID: tx.id, kind: .transfer) }
                    close()
                } label: {
                    Text("Это перевод").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            if tx.kind.isOutgoing {
                Button {
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
        store.mutate { $0.categorize(transactionID: tx.id, categoryID: category.id, createRule: rule) }
        close()
    }

    private func close() {
        let current = store.data.transaction(transactionID)?.note ?? ""
        if noteLoaded && note != current {
            let text = note
            store.mutate { $0.setNote(transactionID: transactionID, note: text) }
        }
        dismiss()
    }
}
