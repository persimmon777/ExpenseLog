import Foundation
import UserNotifications

// MARK: - Тексты и пороги (чистая логика над AppData)

/// Уведомление, которое нужно показать сразу.
struct InstantAlert {
    let id: String
    let body: String
}

extension AppData {

    /// Пороги 80% / 100% лимитов категорий (раз в месяц) и плана на неделю (раз в неделю),
    /// пересечённые сейчас и ещё не отправленные. Помечает их отправленными в `limitAlertsSent`.
    mutating func collectLimitAlerts(now: Date = Date()) -> [InstantAlert] {
        var alerts: [InstantAlert] = []
        let monthKey = String(Fmt.dayKey(now).prefix(7))

        func threshold(_ status: LimitStatus) -> Int? {
            if status.ratio >= 1 { return 100 }
            if status.ratio >= 0.8 { return 80 }
            return nil
        }

        for category in categories {
            guard let status = limitStatus(for: category, now: now), let level = threshold(status) else { continue }
            let key = "\(category.id.uuidString)|\(monthKey)"
            guard level > (limitAlertsSent[key] ?? 0) else { continue }
            limitAlertsSent[key] = level
            let amounts = "\(Fmt.money(status.spent)) из \(Fmt.money(status.limit))"
            let body = level == 100
                ? "\(category.name): лимит исчерпан (\(amounts))"
                : "\(category.name): потрачено 80% лимита (\(amounts))"
            alerts.append(InstantAlert(id: "limit-\(category.id.uuidString)-\(monthKey)-\(level)", body: body))
        }

        if let status = planStatus(.week, containing: now), let level = threshold(status) {
            let weekKey = Fmt.dayKey(weekStart(now))
            let key = "plan|\(weekKey)"
            if level > (limitAlertsSent[key] ?? 0) {
                limitAlertsSent[key] = level
                let amounts = "\(Fmt.money(status.spent)) из \(Fmt.money(status.limit))"
                let body = level == 100
                    ? "План на неделю исчерпан (\(amounts))"
                    : "План на неделю: потрачено 80% (\(amounts))"
                alerts.append(InstantAlert(id: "plan-\(weekKey)-\(level)", body: body))
            }
        }
        return alerts
    }

    /// «Неделя: 186,40 BYN. Больше всего — Кафе (54,00 BYN). На 12,4% меньше, чем на прошлой неделе.»
    func weeklySummaryText(weekContaining date: Date) -> String {
        let s = summary(.week, containing: date)
        guard s.total > 0 else { return "На этой неделе трат не было" }
        var text = "Неделя: \(Fmt.money(s.total))."
        if let top = s.categories.first(where: { $0.categoryID != nil }) ?? s.categories.first {
            text += " Больше всего — \(top.name) (\(Fmt.money(top.total)))."
        }
        if let plan = s.plan {
            text += s.total > plan
                ? " План \(Fmt.money(plan)) превышен на \(Fmt.money(s.total - plan))."
                : " В план \(Fmt.money(plan)) уложились."
        }
        if let comparison = s.comparisonText {
            text += " \(comparison)."
        }
        return text
    }
}

// MARK: - Планирование (локальные уведомления)

/// Локальные уведомления (CLAUDE.md, раздел 7). Вызывается после каждого изменения данных,
/// при открытии приложения и из App Intent.
enum Notifier {
    static let weeklyID = "weekly-summary"

    private static var center: UNUserNotificationCenter { .current() }

    /// Спросить разрешение (если ещё не спрашивали).
    @discardableResult
    static func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func isAuthorized() async -> Bool {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
    }

    /// Пороги лимитов → сразу; сводка → ближайшее воскресенье 20:00; долги → в день возврата 10:00.
    static func refresh(now: Date = Date()) async {
        guard await isAuthorized() else { return }

        if SharedSettings.isEnabled(SharedSettings.Key.notifyLimits) {
            var alerts: [InstantAlert] = []
            DataFile.update { data in
                alerts = data.collectLimitAlerts(now: now)
            }
            for alert in alerts {
                await add(id: alert.id, body: alert.body, trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false))
            }
        }

        let data = DataFile.load()
        await scheduleWeekly(data, now: now)
        await scheduleDebts(data, now: now)
    }

    /// Пробное уведомление через 5 секунд.
    static func sendTest() async {
        await add(id: "test-\(UUID().uuidString)", body: "Уведомления работают. Можно закрыть приложение — напоминания придут сами.",
                  trigger: UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false))
    }

    private static func scheduleWeekly(_ data: AppData, now: Date) async {
        center.removePendingNotificationRequests(withIdentifiers: [weeklyID])
        guard SharedSettings.isEnabled(SharedSettings.Key.notifyWeeklySummary) else { return }
        var match = DateComponents()
        match.weekday = 1 // воскресенье
        match.hour = 20
        match.minute = 0
        guard let fire = Fmt.calendar.nextDate(after: now, matching: match, matchingPolicy: .nextTime) else { return }
        let parts = Fmt.calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
        await add(id: weeklyID, body: data.weeklySummaryText(weekContaining: fire),
                  trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false))
    }

    private static func scheduleDebts(_ data: AppData, now: Date) async {
        let pending = await center.pendingNotificationRequests()
        let old = pending.map(\.identifier).filter { $0.hasPrefix("debt-") }
        center.removePendingNotificationRequests(withIdentifiers: old)
        guard SharedSettings.isEnabled(SharedSettings.Key.notifyDebts) else { return }
        let cal = Fmt.calendar
        for debt in data.activeDebts {
            guard let due = debt.dueDate,
                  let fire = cal.date(bySettingHour: 10, minute: 0, second: 0, of: due),
                  fire > now else { continue }
            let parts = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            await add(id: "debt-\(debt.id.uuidString)",
                      body: "Сегодня \(debt.person) должен вернуть \(Fmt.money(debt.amount, currency: debt.currency))",
                      trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false))
        }
    }

    private static func add(id: String, body: String, trigger: UNNotificationTrigger) async {
        let content = UNMutableNotificationContent()
        content.title = "Spent"
        content.body = body
        content.sound = .default
        try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
}
