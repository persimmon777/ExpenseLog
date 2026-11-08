import SwiftUI
import WidgetKit

/// Данные для экранов. Источник истины — файл (`DataFile`): App Intent может
/// изменить его, пока приложение открыто, поэтому каждое изменение — через `mutate`,
/// а при возвращении в приложение — `reload()`.
@MainActor
final class SpentStore: ObservableObject {
    @Published private(set) var data: AppData

    init() {
        data = DataFile.load()
    }

    /// Перечитать файл (при `scenePhase == .active`).
    func reload() {
        data = DataFile.load()
    }

    /// Прочитать свежие данные с диска → изменить → записать → обновить экран.
    @discardableResult
    func mutate<T>(_ change: (inout AppData) -> T) -> T {
        var result: T?
        data = DataFile.update { result = change(&$0) }
        afterChange()
        return result!
    }

    /// Что делать после любого изменения данных.
    /// Порядок по CLAUDE.md: лимиты → weekly-summary → резервная копия → виджет.
    /// Резервная копия появится на своём шаге.
    private func afterChange() {
        WidgetCenter.shared.reloadAllTimelines()
        Task { await Notifier.refresh() }
    }

    /// При открытии приложения: перечитать файл и пересчитать уведомления.
    func becameActive() {
        reload()
        Task { await Notifier.refresh() }
    }
}
