import SwiftUI

/// Поле «Магазин» для самоопределения платежа: можно вписать (например, «ozon»)
/// или выбрать из магазинов, где уже были покупки.
struct MerchantField: View {
    @EnvironmentObject private var store: SpentStore
    @Environment(\.theme) private var theme
    @Binding var name: String

    var body: some View {
        let merchants = Array(store.data.merchants().prefix(30))
        HStack {
            TextField("Магазин, например ozon", text: $name)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !merchants.isEmpty {
                Menu {
                    ForEach(merchants) { m in
                        Button(m.name) { name = m.originalName }
                    }
                } label: {
                    Image(systemName: "list.bullet")
                        .foregroundStyle(theme.accent)
                }
                .accessibilityLabel("Выбрать из истории")
            }
        }
    }
}

extension String {
    /// Ключ магазина для самоопределения или `nil`, если поле пустое.
    var merchantKeyOrNil: String? {
        let key = Merchant.key(self)
        return key.isEmpty ? nil : key
    }
}
