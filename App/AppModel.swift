import SwiftUI
import WidgetKit

/// App-wide state. Every settings change is written to the shared App Group and
/// the matching widget is asked to redraw.
@Observable
final class AppModel {
    var global: GlobalSettings {
        didSet { guard global != oldValue else { return }; SharedStore.global = global; reloadAllWidgets() }
    }
    var daylight: DaylightSettings {
        didSet { guard daylight != oldValue else { return }; SharedStore.daylight = daylight; reload(WidgetKind.daylight) }
    }
    var agenda: AgendaSettings {
        didSet { guard agenda != oldValue else { return }; SharedStore.agenda = agenda; reload(WidgetKind.agenda) }
    }
    var gazette: GazetteSettings {
        didSet { guard gazette != oldValue else { return }; SharedStore.gazette = gazette; reload(WidgetKind.gazette) }
    }
    var month: MonthSettings {
        didSet { guard month != oldValue else { return }; SharedStore.month = month; reload(WidgetKind.month) }
    }
    var flip: FlipSettings {
        didSet { guard flip != oldValue else { return }; SharedStore.flip = flip; reload(WidgetKind.flip) }
    }
    var drawerList: DrawerList {
        didSet { guard drawerList != oldValue else { return }; SharedStore.drawers = drawerList; reload(WidgetKind.launcher) }
    }

    /// Which look the gallery previews use.
    var previewLook: WidgetLook = .light

    // Live data for previews
    var weather: WeatherSnapshot?
    var news: NewsSnapshot?
    var events: [AgendaEvent] = []
    var reminders: [ReminderItem] = []
    var eventDays: Set<Date> = []
    var hasCalendarAccess = CalendarService.hasEventAccess
    var hasReminderAccess = CalendarService.hasReminderAccess
    var isRefreshing = false

    init() {
        global = SharedStore.global
        daylight = SharedStore.daylight
        agenda = SharedStore.agenda
        gazette = SharedStore.gazette
        month = SharedStore.month
        flip = SharedStore.flip
        drawerList = SharedStore.drawers
        weather = WeatherService.cached
        news = NewsService.cached(for: SharedStore.gazette.resolvedFeedURL)
    }

    /// Picks up changes the widgets made (month arrows, agenda buttons).
    func reloadFromStore() {
        month = SharedStore.month
        agenda = SharedStore.agenda
        hasCalendarAccess = CalendarService.hasEventAccess
        hasReminderAccess = CalendarService.hasReminderAccess
    }

    func refreshData(force: Bool = false) async {
        isRefreshing = true
        defer { isRefreshing = false }
        if let location = global.location {
            if force, let fresh = try? await WeatherService.fetch(for: location) {
                SharedStore.save(fresh, SharedStore.Key.weather)
                weather = fresh
            } else {
                weather = await WeatherService.current(for: location)
            }
        }
        if let feed = gazette.resolvedFeedURL {
            news = await NewsService.headlines(from: feed, maxAge: force ? 0 : 45 * 60)
        } else {
            news = nil
        }
        refreshCalendar()
        reminders = await CalendarService.reminders(listIDs: gazette.reminderListIDs, limit: 4)
        reloadAllWidgets()
    }

    func refreshCalendar() {
        hasCalendarAccess = CalendarService.hasEventAccess
        hasReminderAccess = CalendarService.hasReminderAccess
        let start = Calendar.current.startOfDay(for: .now)
        events = CalendarService.events(from: start, days: 8, limit: 40)
        let cal = Calendar.current
        let thisMonth = cal.date(from: cal.dateComponents([.year, .month], from: .now)) ?? .now
        let from = cal.date(byAdding: .month, value: month.monthOffset, to: thisMonth) ?? thisMonth
        let to = cal.date(byAdding: .month, value: 2, to: from) ?? from
        eventDays = CalendarService.daysWithEvents(in: DateInterval(start: from, end: to))
    }

    func requestCalendarAccess() async {
        _ = await CalendarService.requestEventAccess()
        refreshCalendar()
        reloadAllWidgets()
    }

    func requestReminderAccess() async {
        _ = await CalendarService.requestReminderAccess()
        hasReminderAccess = CalendarService.hasReminderAccess
        reminders = await CalendarService.reminders(listIDs: gazette.reminderListIDs, limit: 4)
        reload(WidgetKind.gazette)
    }

    // MARK: Preview data (real when available, samples otherwise)

    var previewEvents: [AgendaEvent] {
        hasCalendarAccess ? events : AgendaEvent.samples()
    }
    var previewWeather: WeatherSnapshot? { weather ?? (global.location == nil ? .sample : nil) }
    var previewReminders: [ReminderItem] { hasReminderAccess ? reminders : ReminderItem.samples }
    var previewNews: NewsSnapshot? {
        guard gazette.news != .none else { return nil }
        return news ?? .sample
    }

    // MARK: Drawers

    func addDrawer() -> Drawer {
        var drawer = Drawer()
        drawer.name = "Drawer \(drawerList.drawers.count + 1)"
        drawerList.drawers.append(drawer)
        return drawer
    }

    func updateDrawer(_ drawer: Drawer) {
        guard let index = drawerList.drawers.firstIndex(where: { $0.id == drawer.id }) else { return }
        drawerList.drawers[index] = drawer
    }

    func deleteDrawer(_ drawer: Drawer) {
        for app in drawer.apps { ImageStore.delete(app.iconFile, in: ImageStore.iconsFolder) }
        ImageStore.delete(drawer.photoFile, in: ImageStore.backgroundsFolder)
        drawerList.drawers.removeAll { $0.id == drawer.id }
        if drawerList.drawers.isEmpty { drawerList.drawers = [Drawer()] }
    }

    // MARK: URLs

    /// glassboard://launch?url=… comes from launcher widgets in "through the app" mode.
    func handle(_ url: URL) {
        guard url.scheme == "glassboard", url.host == "launch",
              let target = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "url" })?.value,
              let targetURL = URL(string: target)
        else { return }
        UIApplication.shared.open(targetURL)
    }

    // MARK: Widgets

    func reload(_ kind: String) {
        WidgetCenter.shared.reloadTimelines(ofKind: kind)
    }

    func reloadAllWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}

extension Appearance {
    var colorScheme: ColorScheme? {
        switch self {
        case .auto: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
