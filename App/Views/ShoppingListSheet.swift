import SwiftUI

/// Список покупок: галочки, примерные цены, сумма того, что ещё не куплено.
struct ShoppingListSheet: View {
    @EnvironmentObject private var store: SpentStore
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var newTitle = ""
    @State private var newPrice = ""
    @State private var editing: ShoppingItem?
    /// Открыта строка добавления (по «+» рядом с «Купить»).
    @State private var isAdding = false
    @FocusState private var focus: Field?

    private enum Field {
        case title, price
    }

    var body: some View {
        let data = store.data
        let toBuy = data.shoppingToBuy
        let bought = data.shoppingBought

        NavigationStack {
            List {
                Section {
                    AmountRow(title: "Осталось купить", value: Fmt.money(data.plannedTotal), emphasized: true)
                        .listRowBackground(theme.paper)
                    if let balance = data.lastBalance, data.plannedTotal > 0 {
                        AmountRow(title: "Останется на карте", value: Fmt.money(balance - data.plannedTotal))
                            .listRowBackground(theme.paper)
                    }
                }

                Section {
                    if isAdding {
                        addRow
                            .listRowBackground(theme.paper)
                    }
                    ForEach(toBuy) { item in
                        itemRow(item)
                    }
                } header: {
                    HStack(spacing: 6) {
                        header("Купить")
                        Button {
                            startAdding()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(theme.accent)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Добавить покупку")
                        Spacer()
                    }
                } footer: {
                    if toBuy.isEmpty && !isAdding {
                        Text("Нажмите «+», чтобы добавить, что собираетесь купить, и примерную цену — сумма появится на главной.")
                            .foregroundStyle(theme.inkSoft)
                    } else if !toBuy.isEmpty {
                        Text("Проведите вправо → «Изменить», чтобы указать магазин: пункт отметится сам, когда придёт оплата.")
                            .foregroundStyle(theme.inkSoft)
                    }
                }

                if !bought.isEmpty {
                    Section {
                        ForEach(bought) { item in
                            itemRow(item)
                        }
                        Button("Убрать купленное", role: .destructive) {
                            store.mutate { $0.clearBoughtShopping() }
                        }
                        .listRowBackground(theme.paper)
                    } header: {
                        header("Куплено")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .themedBackground(theme)
            .navigationTitle("Список покупок")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") {
                        addItem()
                        dismiss()
                    }
                }
            }
            .sheet(item: $editing) { item in
                ShoppingItemEditSheet(item: item)
                    .environmentObject(store)
                    .environment(\.theme, theme)
                    .preferredColorScheme(theme.colorScheme)
                    .tint(theme.accent)
            }
        }
    }

    // MARK: Части

    /// Строка добавления: кружок, название, цена в «пилюле», крестик «отменить».
    private var addRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "circle")
                .font(.title3)
                .foregroundStyle(theme.rule)
            TextField("Что купить", text: $newTitle)
                .foregroundStyle(theme.ink)
                .focused($focus, equals: .title)
                .submitLabel(.next)
                .onSubmit { focus = .price }
            HStack(spacing: 2) {
                Text("≈")
                    .foregroundStyle(theme.inkSoft)
                TextField("цена", text: $newPrice)
                    // У цифровой клавиатуры нет кнопки «ввод» — эта раскладка с цифрами её имеет.
                    .keyboardType(.numbersAndPunctuation)
                    .submitLabel(.done)
                    .multilineTextAlignment(.trailing)
                    .font(theme.amountFont(.body))
                    .foregroundStyle(theme.ink)
                    .focused($focus, equals: .price)
                    .onSubmit {
                        addItem()
                        focus = .title
                    }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(width: 96)
            .background(theme.background, in: Capsule())
            Button {
                cancelAdding()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(theme.inkSoft)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Отменить")
        }
    }

    private func itemRow(_ item: ShoppingItem) -> some View {
        Button {
            let id = item.id
            withAnimation { store.mutate { $0.toggleShoppingItem(id) } }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.isDone ? theme.positive : theme.inkSoft)
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.title)
                        .foregroundStyle(item.isDone ? theme.inkSoft : theme.ink)
                        .strikethrough(item.isDone, color: theme.inkSoft)
                    if let shop = item.merchantName {
                        Text(item.matchedTransactionID != nil && item.isDone ? "отмечено само · \(shop)" : "в \(shop) · отметится само")
                            .font(.caption2)
                            .foregroundStyle(item.matchedTransactionID != nil && item.isDone ? theme.positive : theme.inkSoft)
                    }
                }
                Spacer(minLength: 8)
                Text(item.price.map { Fmt.money($0) } ?? "—")
                    .font(theme.amountFont(.body))
                    .foregroundStyle(item.isDone ? theme.inkSoft : theme.ink)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(theme.paper)
        .listRowSeparatorTint(theme.rule)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                let id = item.id
                store.mutate { $0.deleteShoppingItem(id) }
            } label: {
                Label("Удалить", systemImage: "trash")
            }
        }
        .contextMenu {
            Button {
                editing = item
            } label: {
                Label("Изменить", systemImage: "pencil")
            }
        }
        .swipeActions(edge: .leading) {
            Button {
                editing = item
            } label: {
                Label("Изменить", systemImage: "pencil")
            }
            .tint(theme.accent)
        }
    }

    private func header(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(theme.inkSoft)
            .textCase(nil)
    }

    // MARK: Действия

    private func startAdding() {
        withAnimation { isAdding = true }
        // Поле появляется с анимацией — фокус ставим, когда оно уже на экране.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { focus = .title }
    }

    private func cancelAdding() {
        newTitle = ""
        newPrice = ""
        focus = nil
        withAnimation { isAdding = false }
    }

    private func addItem() {
        let title = newTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        let price = SMSParser.decimal(newPrice.replacingOccurrences(of: " ", with: ""))
        store.mutate { $0.addShoppingItem(title: title, price: price) }
        newTitle = ""
        newPrice = ""
    }
}
