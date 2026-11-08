import SwiftUI
import UIKit

/// «Уведомления»: сводка, лимиты и план, долги — отдельные переключатели.
struct NotificationSettingsView: View {
    @Environment(\.theme) private var theme
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage(SharedSettings.Key.notifyWeeklySummary, store: AppGroup.defaults) private var weekly = true
    @AppStorage(SharedSettings.Key.notifyLimits, store: AppGroup.defaults) private var limits = true
    @AppStorage(SharedSettings.Key.notifyDebts, store: AppGroup.defaults) private var debts = true
    @AppStorage(SharedSettings.Key.notifyRecurring, store: AppGroup.defaults) private var recurring = true

    @State private var authorized = true
    @State private var testSent = false

    var body: some View {
        Form {
            if !authorized {
                Section {
                    Text("Уведомления для Coin выключены в настройках iPhone. Включите их, иначе напоминания не придут.")
                        .foregroundStyle(theme.danger)
                    Button("Открыть настройки iPhone") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                }
            }
            Section {
                Toggle(isOn: $weekly) {
                    label("Еженедельная сводка", "В воскресенье в 20:00: сколько потрачено за неделю, на что больше всего и сравнение с прошлой.")
                }
                Toggle(isOn: $limits) {
                    label("Лимиты и план", "Сразу после покупки, когда потрачено 80% и 100% лимита категории или плана на неделю. Каждое — один раз.")
                }
                Toggle(isOn: $debts) {
                    label("Долги", "В день возврата в 10:00: «Сегодня Петя должен вернуть 20 BYN».")
                }
                Toggle(isOn: $recurring) {
                    label("Регулярные платежи", "Накануне списания в 19:00 и в день поступления в 10:00.")
                }
            }
            .tint(theme.accent)
            Section {
                Button(testSent ? "Отправлено — придёт через 5 секунд" : "Проверить уведомление") {
                    Task {
                        await Notifier.requestAuthorization()
                        await Notifier.sendTest()
                        testSent = true
                        authorized = await Notifier.isAuthorized()
                    }
                }
                .disabled(testSent)
            } footer: {
                Text("Можно сразу выйти на экран «Домой» — уведомление должно появиться сверху.")
            }
        }
        .themedBackground(theme)
        .navigationTitle("Уведомления")
        .navigationBarTitleDisplayMode(.inline)
        .task { await updateStatus() }
        .onChange(of: weekly) { _, _ in changed() }
        .onChange(of: limits) { _, _ in changed() }
        .onChange(of: debts) { _, _ in changed() }
        .onChange(of: recurring) { _, _ in changed() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await updateStatus() } }
        }
    }

    private func label(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .foregroundStyle(theme.ink)
            Text(text)
                .font(.caption)
                .foregroundStyle(theme.inkSoft)
        }
    }

    private func changed() {
        Task {
            await Notifier.requestAuthorization()
            await Notifier.refresh()
            await updateStatus()
        }
    }

    private func updateStatus() async {
        authorized = await Notifier.isAuthorized()
    }
}
