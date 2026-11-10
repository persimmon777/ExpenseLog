import SwiftUI

/// Конверты бюджета на месяц на главной: сколько можно сегодня по каждому и полоска «потрачено из заложенного».
struct EnvelopesView: View {
    @Environment(\.theme) private var theme
    let snapshot: MonthlyBudgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(snapshot.envelopes) { envelope in
                row(envelope)
            }
        }
    }

    private func row(_ envelope: EnvelopeStatus) -> some View {
        let over = envelope.canSpendToday < 0
        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(envelope.category.emoji) \(envelope.category.name)")
                    .font(.subheadline)
                    .foregroundStyle(theme.ink)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(over ? "перерасход \(Fmt.money(-envelope.canSpendToday))" : "можно \(Fmt.money(envelope.canSpendToday)) сегодня")
                    .font(theme.amountFont(.subheadline))
                    .foregroundStyle(over ? theme.danger : theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            LimitBar(status: envelope.status)
            Text(caption(envelope))
                .font(.caption2)
                .foregroundStyle(envelope.remaining < 0 ? theme.danger : theme.inkSoft)
        }
    }

    /// «64,00 из 150,00 BYN · запланировано 20,00».
    private func caption(_ envelope: EnvelopeStatus) -> String {
        var text = "\(Fmt.money(envelope.spent)) из \(Fmt.money(envelope.allocation))"
        if envelope.planned > 0 { text += " · запланировано \(Fmt.money(envelope.planned))" }
        if envelope.remaining < 0 { text += " · сверх конверта \(Fmt.money(-envelope.remaining)) из свободных" }
        return text
    }
}
