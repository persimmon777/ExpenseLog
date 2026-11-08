import SwiftUI

/// Главная вкладка «Чеки» (CLAUDE.md, 5.1).
struct ChecksView: View {
    @EnvironmentObject private var store: SpentStore
    @Environment(\.theme) private var theme

    @State private var editing: EditTarget?
    @State private var showManual = false
    @State private var showBalance = false
    @State private var showPaste = false
    @State private var removed: Transaction?
    @State private var undoTask: Task<Void, Never>?

    var body: some View {
        let uncategorized = store.data.uncategorized
        let history = store.data.historyByDay()

        NavigationStack {
            List {
                SummaryCard { showBalance = true }
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                if !uncategorized.isEmpty {
                    Section {
                        ForEach(uncategorized) { tx in row(tx, sorting: true) }
                    } header: {
                        sectionHeader("Без категории · \(uncategorized.count)")
                    } footer: {
                        Text("Нажмите на покупку и выбирайте категории подряд — после выбора сразу откроется следующая.")
                            .foregroundStyle(theme.inkSoft)
                    }
                }

                if history.isEmpty {
                    Section {
                        Text("Операций пока нет. Скопируйте SMS банка и нажмите «Вставить SMS» или добавьте операцию кнопкой «+».")
                            .font(.footnote)
                            .foregroundStyle(theme.inkSoft)
                            .listRowBackground(theme.paper)
                    }
                }

                ForEach(history) { group in
                    Section {
                        ForEach(group.items) { tx in row(tx) }
                    } header: {
                        sectionHeader(Fmt.dayTitle(group.day))
                    }
                }
            }
            .listStyle(.insetGrouped)
            .themedBackground(theme)
            .navigationTitle("Чеки")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showPaste = true
                    } label: {
                        Label("Вставить SMS", systemImage: "doc.on.clipboard")
                            .labelStyle(.titleAndIcon)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showManual = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Добавить операцию")
                }
            }
            .sheet(item: $editing) { target in
                themed(TransactionSheet(transactionID: target.transactionID, sortingQueue: target.sortingQueue))
            }
            .sheet(isPresented: $showBalance) {
                themed(BalanceSheet())
            }
            .sheet(isPresented: $showManual) {
                themed(ManualTransactionSheet())
            }
            .sheet(isPresented: $showPaste) {
                themed(PasteSMSSheet())
            }
            .overlay(alignment: .bottom) {
                if let removed {
                    UndoToast(text: "Удалено: \(store.data.displayTitle(for: removed))") { undoDelete(removed) }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }

    // MARK: Части

    private func row(_ tx: Transaction, sorting: Bool = false) -> some View {
        Button {
            editing = EditTarget(transactionID: tx.id, sortingQueue: sorting)
        } label: {
            TransactionRow(tx: tx, title: store.data.displayTitle(for: tx), category: store.data.category(tx.categoryID))
        }
        .buttonStyle(.plain)
        .listRowBackground(theme.paper)
        .listRowSeparatorTint(theme.rule)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                delete(tx)
            } label: {
                Label("Удалить", systemImage: "trash")
            }
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(theme.inkSoft)
            .textCase(nil)
    }

    /// Листы получают тему и данные явно.
    private func themed<V: View>(_ view: V) -> some View {
        view
            .environmentObject(store)
            .environment(\.theme, theme)
            .preferredColorScheme(theme.colorScheme)
            .tint(theme.accent)
    }

    // MARK: Удаление с отменой

    private func delete(_ tx: Transaction) {
        guard let gone = store.mutate({ $0.deleteTransaction(tx.id) }) else { return }
        undoTask?.cancel()
        withAnimation { removed = gone }
        undoTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled else { return }
            withAnimation { removed = nil }
        }
    }

    private func undoDelete(_ tx: Transaction) {
        undoTask?.cancel()
        store.mutate { $0.restoreTransaction(tx) }
        withAnimation { removed = nil }
    }
}

/// Какую операцию открыть и в каком режиме.
private struct EditTarget: Identifiable {
    let id = UUID()
    let transactionID: UUID
    /// Открыто из «Без категории»: после выбора категории сразу следующая.
    let sortingQueue: Bool
}
