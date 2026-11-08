import SwiftUI
import UIKit

/// «Вставить SMS»: текст из буфера → предпросмотр → «Добавить N операций».
struct PasteSMSSheet: View {
    @EnvironmentObject private var store: SpentStore
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var loaded = false
    @State private var resultText: String?

    var body: some View {
        let parsed = SMSParser.parseAll(text)
        let newCount = Set(parsed.filter { store.data.previewStatus($0) == .new }.map(\.fingerprint)).count

        NavigationStack {
            List {
                Section {
                    TextField("Вставьте сюда одно или несколько SMS банка", text: $text, axis: .vertical)
                        .lineLimit(3...8)
                        .font(.footnote.monospaced())
                        .listRowBackground(theme.paper)
                    Button("Вставить из буфера") { pasteFromClipboard() }
                        .listRowBackground(theme.paper)
                } header: {
                    Text("Текст SMS")
                }

                if let resultText {
                    Section {
                        Text(resultText)
                            .foregroundStyle(theme.positive)
                            .listRowBackground(theme.paper)
                    }
                }

                if !parsed.isEmpty {
                    Section {
                        ForEach(Array(parsed.enumerated()), id: \.offset) { _, sms in
                            previewRow(sms)
                                .listRowBackground(theme.paper)
                        }
                    } header: {
                        Text("Найдено: \(Fmt.plural(parsed.count, "операция", "операции", "операций"))")
                    }
                } else if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Section {
                        Text("В тексте нет SMS об оплате, пополнении или снятии наличных.")
                            .foregroundStyle(theme.inkSoft)
                            .listRowBackground(theme.paper)
                    }
                }
            }
            .themedBackground(theme)
            .navigationTitle("Вставить SMS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(resultText == nil ? "Отменить" : "Готово") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if newCount > 0 {
                    Button {
                        add()
                    } label: {
                        Text("Добавить \(Fmt.plural(newCount, "операцию", "операции", "операций"))")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(16)
                    .background(theme.background)
                }
            }
        }
        .onAppear {
            guard !loaded else { return }
            loaded = true
            pasteFromClipboard()
        }
    }

    private func previewRow(_ sms: ParsedSMS) -> some View {
        let status = store.data.previewStatus(sms)
        return HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(sms.type == .payment ? store.data.merchantName(sms.place) : (sms.type == .topUp ? "Пополнение" : "Снятие наличных"))
                    .lineLimit(1)
                Text(statusText(status, sms: sms))
                    .font(.caption)
                    .foregroundStyle(status == .new ? theme.inkSoft : theme.danger)
            }
            Spacer(minLength: 8)
            Text(Fmt.signedMoney(sms.amount, outgoing: sms.type.txKind.isOutgoing, currency: sms.currency))
                .font(theme.amountFont(.body))
                .foregroundStyle(status == .new ? theme.ink : theme.inkSoft)
                .strikethrough(status != .new)
        }
    }

    private func statusText(_ status: AppData.PreviewStatus, sms: ParsedSMS) -> String {
        switch status {
        case .new:
            if let date = sms.date { return "\(Fmt.dayTitle(date)), \(Fmt.time(date))" }
            return "Новая"
        case .duplicate:
            return "Уже есть — не добавится"
        case .previouslyDeleted:
            return "Вы её удаляли — не добавится"
        }
    }

    private func pasteFromClipboard() {
        if let clip = UIPasteboard.general.string, !clip.isEmpty {
            text = clip
            resultText = nil
        }
    }

    private func add() {
        let input = text
        let r = store.mutate { $0.ingest(smsText: input) }
        var parts = ["Добавлено \(r.added.count)"]
        if r.duplicates > 0 { parts.append("дублей \(r.duplicates)") }
        if r.previouslyDeleted > 0 { parts.append("ранее удалено \(r.previouslyDeleted)") }
        if !r.matched.isEmpty { parts.append("отмечено само: " + r.matched.joined(separator: "; ")) }
        resultText = parts.joined(separator: ", ")
    }
}
