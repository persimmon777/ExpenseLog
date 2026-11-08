import SwiftUI
import UIKit

/// «Диагностика»: почему не найдена общая папка (виджет не видит данные).
struct DiagnosticsView: View {
    @Environment(\.theme) private var theme
    @State private var copied = false

    var body: some View {
        let text = AppGroup.diagnostics
        Form {
            Section {
                Text(AppGroup.isShared
                     ? "Общая папка работает: приложение и виджет видят одни и те же данные."
                     : "Общая папка не найдена: данные сохраняются только внутри приложения, виджет их не видит. Пришлите скриншот этого экрана — по нему видно, что разрешил SideStore.")
                    .foregroundStyle(AppGroup.isShared ? theme.positive : theme.danger)
            }
            Section("Подробности") {
                Text(text)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
                Button(copied ? "Скопировано" : "Скопировать") {
                    UIPasteboard.general.string = text
                    copied = true
                }
            }
            Section {
                Text("1. Если ставите через SideStore — включите в его настройках «Auto-Fix AppGroup IDs». Если через iloader — пришлите скриншот этого экрана.\n2. Переустановите Coin — данные не пропадут, Coin сам перенесёт их в общую папку.\n3. Удалите виджет и добавьте заново.")
                    .font(.footnote)
                    .foregroundStyle(theme.inkSoft)
            } header: {
                Text("Что попробовать")
            }
        }
        .themedBackground(theme)
        .navigationTitle("Диагностика")
        .navigationBarTitleDisplayMode(.inline)
    }
}
