import AppIntents
import WidgetKit

// MARK: - Month widget arrows

struct ShiftMonthIntent: AppIntent {
    static var title: LocalizedStringResource = "Change Month"
    static var isDiscoverable: Bool = false

    /// -1 = previous month, +1 = next month, 0 = back to this month.
    @Parameter(title: "Change") var delta: Int

    init() { delta = 0 }
    init(delta: Int) { self.delta = delta }

    func perform() async throws -> some IntentResult {
        var settings = SharedStore.month
        settings.monthOffset = delta == 0 ? 0 : max(-24, min(24, settings.monthOffset + delta))
        SharedStore.month = settings
        return .result()
    }
}

// MARK: - Agenda widget mode buttons

extension AgendaMode: AppEnum {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Agenda View"
    static var caseDisplayRepresentations: [AgendaMode: DisplayRepresentation] = [
        .next: "Now",
        .week: "Week",
        .sky: "Sky",
    ]
}

struct SetAgendaModeIntent: AppIntent {
    static var title: LocalizedStringResource = "Switch Agenda View"
    static var isDiscoverable: Bool = false

    @Parameter(title: "View") var mode: AgendaMode

    init() { mode = .next }
    init(mode: AgendaMode) { self.mode = mode }

    func perform() async throws -> some IntentResult {
        var settings = SharedStore.agenda
        settings.mode = mode
        SharedStore.agenda = settings
        return .result()
    }
}

// MARK: - Launcher

/// Used by the small launcher widget, where every icon needs to be a button.
struct LaunchAppIntent: AppIntent {
    static var title: LocalizedStringResource = "Open App"
    static var isDiscoverable: Bool = false

    @Parameter(title: "URL") var url: URL

    init() { url = URL(string: "glassboard://")! }
    init(url: URL) { self.url = url }

    func perform() async throws -> some IntentResult & OpensIntent {
        .result(opensIntent: OpenURLIntent(url))
    }
}

struct DrawerEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Drawer"
    static var defaultQuery = DrawerQuery()

    var id: String
    var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct DrawerQuery: EntityQuery {
    func entities(for identifiers: [DrawerEntity.ID]) async throws -> [DrawerEntity] {
        allDrawers().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [DrawerEntity] {
        allDrawers()
    }

    func defaultResult() async -> DrawerEntity? {
        allDrawers().first
    }

    private func allDrawers() -> [DrawerEntity] {
        SharedStore.drawers.drawers.map { DrawerEntity(id: $0.id.uuidString, name: $0.name) }
    }
}

struct SelectDrawerIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Choose Drawer"
    static var description = IntentDescription("Pick which drawer of apps this widget shows.")

    @Parameter(title: "Drawer") var drawer: DrawerEntity?

    init() {}
}
