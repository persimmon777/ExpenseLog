import SwiftUI

/// Строка операции в списках.
struct TransactionRow: View {
    @Environment(\.theme) private var theme
    let tx: Transaction
    /// Заголовок с учётом своего названия магазина (`AppData.displayTitle`).
    let title: String
    let category: Category?

    var body: some View {
        HStack(spacing: 12) {
            icon
                .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundStyle(theme.ink)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(tx.isUncategorized ? theme.accent : theme.inkSoft)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(Fmt.signedMoney(tx.amount, outgoing: tx.kind.isOutgoing, currency: tx.currency))
                .font(theme.amountFont(.body))
                .foregroundStyle(amountColor)
                .strikethrough(tx.isExcluded, color: theme.inkSoft)
                .lineLimit(1)
        }
        .contentShape(Rectangle())
    }

    private var subtitle: String {
        var parts: [String] = []
        if tx.kind == .expense {
            parts.append(category?.name ?? "Без категории")
        } else {
            parts.append(tx.kind.title)
        }
        if let place = tx.placeSubtitle { parts.append(place) }
        if tx.isExcluded { parts.append("не в расчёте") }
        parts.append(Fmt.time(tx.date))
        if tx.note != nil { parts.append("✎") }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private var icon: some View {
        if tx.kind == .expense, let category {
            Text(category.emoji)
                .font(.title3)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(hex: category.colorHex).opacity(0.18), in: Circle())
        } else {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(tx.isUncategorized ? theme.accent : theme.inkSoft)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(theme.rule.opacity(0.5), in: Circle())
        }
    }

    private var amountColor: Color {
        if tx.isExcluded { return theme.inkSoft }
        return tx.kind.isOutgoing ? theme.ink : theme.positive
    }

    private var symbol: String {
        switch tx.kind {
        case .expense: return "questionmark"
        case .income: return "arrow.down"
        case .transfer: return "arrow.left.arrow.right"
        case .debtGiven: return "person.crop.circle.badge.minus"
        case .debtReturn: return "person.crop.circle.badge.checkmark"
        }
    }
}
