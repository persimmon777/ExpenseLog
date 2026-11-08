import SwiftUI

/// Список покупок: галочки, примерные цены, сумма того, что ещё не куплено.
struct ShoppingListSheet: View {
    @EnvironmentObject private var store: SpentStore
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var newTitle = ""
    @State private var newPrice = ""
    @State private var editing: ShoppingItem?
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
                    addRow
                        .listRowBackground(theme.paper)
                    ForEach(toBuy) { item in
                        itemRow(item)
                    }
                } header: {
                    header("Купить")
                } footer: {
                    if toBuy.isEmpty {
                        Text("Добавьте, что собираетесь купить, и примерную цену — сумма появится в чеке на главной.")
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

    private var addRow: some View {
        HStack(spacing: 8) {
            TextField("Что купить", text: $newTitle)
                .focused($focus, equals: .title)
                .submitLabel(.next)
                .onSubmit { focus = .price }
            TextField("≈ цена", text: $newPrice)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(theme.amountFont(.body))
                .frame(width: 90)
                .focused($focus, equals: .price)
            Button {
                addItem()
                focus = .title
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.accent)
            .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
            .accessibilityLabel("Добавить в список")
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
                Text(item.title)
                    .foregroundStyle(item.isDone ? theme.inkSoft : theme.ink)
                    .strikethrough(item.isDone, color: theme.inkSoft)
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

    private func addItem() {
        let title = newTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        let price = SMSParser.decimal(newPrice.replacingOccurrences(of: " ", with: ""))
        store.mutate { $0.addShoppingItem(title: title, price: price) }
        newTitle = ""
        newPrice = ""
    }
}
