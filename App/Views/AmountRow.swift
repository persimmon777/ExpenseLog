import SwiftUI

/// Строка «подпись …… сумма», как в чеке.
struct AmountRow: View {
    @Environment(\.theme) private var theme
    let title: String
    let value: String
    var emphasized = false

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundStyle(emphasized ? theme.ink : theme.inkSoft)
            Spacer(minLength: 12)
            Text(value)
                .font(theme.amountFont(emphasized ? .title2 : .body, weight: emphasized ? .bold : .medium))
                .foregroundStyle(theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }
}
