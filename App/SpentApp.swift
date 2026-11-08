import SwiftUI
import UIKit

// ВРЕМЕННЫЙ КАРКАС. Нужен, чтобы проект собирался и можно было проверить
// установку через SideStore и работу App Group. Экраны — см. CLAUDE.md, «Экраны».
@main
struct SpentApp: App {
    var body: some Scene {
        WindowGroup {
            DiagnosticsView()
        }
    }
}

private struct DiagnosticsView: View {
    @State private var data = DataFile.load()

    var body: some View {
        NavigationStack {
            List {
                Section("Состояние") {
                    LabeledContent("Общая папка (App Group)", value: AppGroup.isShared ? "работает" : "НЕ найдена")
                    LabeledContent("Группа", value: AppGroup.resolvedID ?? "—")
                    LabeledContent("Операций", value: "\(data.transactions.count)")
                    LabeledContent("Категорий", value: "\(data.categories.count)")
                }
                Section {
                    Button("Добавить SMS из буфера обмена") {
                        let text = UIPasteboard.general.string ?? ""
                        data = DataFile.update { _ = $0.ingest(smsText: text) }
                    }
                }
                Section("Последние операции") {
                    ForEach(data.transactions.sorted { $0.date > $1.date }.prefix(20)) { tx in
                        VStack(alignment: .leading) {
                            Text("\(tx.kind.title): \(NSDecimalNumber(decimal: tx.amount).stringValue) \(tx.currency)")
                            Text(tx.merchant).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Spent")
        }
    }
}
