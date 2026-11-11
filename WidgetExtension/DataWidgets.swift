import SwiftUI
import WidgetKit

// MARK: - Agenda

struct AgendaEntry: TimelineEntry {
    let date: Date
    let data: AgendaData
    let settings: AgendaSettings
}

struct AgendaProvider: TimelineProvider {
    func placeholder(in context: Context) -> AgendaEntry {
        let data = AgendaData(date: .now, events: AgendaEvent.samples(), weather: .sample,
                              hasCalendarAccess: true, unit: .auto, locationName: SavedLocation.sample.name)
        return AgendaEntry(date: .now, data: data, settings: AgendaSettings())
    }

    func getSnapshot(in context: Context, completion: @escaping (AgendaEntry) -> Void) {
        if context.isPreview && !CalendarService.hasEventAccess {
            completion(placeholder(in: context))
            return
        }
        Task {
            let entries = await makeEntries(from: .now, count: 1)
            completion(entries[0])
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AgendaEntry>) -> Void) {
        Task {
            // Same data, re-rendered every 5 minutes so "In 12 min" / "Now" stay right.
            let entries = await makeEntries(from: .now, count: 6)
            completion(Timeline(entries: entries, policy: .atEnd))
        }
    }

    private func makeEntries(from now: Date, count: Int) async -> [AgendaEntry] {
        let global = SharedStore.global
        let settings = SharedStore.agenda
        var weather: WeatherSnapshot?
        if let location = global.location {
            weather = await WeatherService.current(for: location)
        }
        let events = CalendarService.events(from: Calendar.current.startOfDay(for: now), days: 8,
                                            calendarIDs: settings.calendarIDs, limit: 40)
        return (0..<count).map { i in
            let date = now.addingTimeInterval(Double(i) * 300)
            let data = AgendaData(date: date, events: events, weather: weather,
                                  hasCalendarAccess: CalendarService.hasEventAccess,
                                  unit: global.temperatureUnit, locationName: global.location?.name)
            return AgendaEntry(date: date, data: data, settings: settings)
        }
    }
}

struct AgendaWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetKind.agenda, provider: AgendaProvider()) { entry in
            LookResolver(appearance: entry.settings.appearance) { look, family in
                AgendaContent(data: entry.data, settings: entry.settings, family: family, look: look, onSelectMode: nil)
                    .containerBackground(for: .widget) { AgendaBackground(look: look) }
            }
        }
        .configurationDisplayName("Agenda")
        .description("Your next event, your week and the sky. Switch views with the side buttons.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

// MARK: - Gazette

struct GazetteEntry: TimelineEntry {
    let date: Date
    let data: GazetteData
    let settings: GazetteSettings
}

struct GazetteProvider: TimelineProvider {
    func placeholder(in context: Context) -> GazetteEntry {
        let location = SavedLocation.sample
        let data = GazetteData(date: .now, events: AgendaEvent.samples(), reminders: ReminderItem.samples,
                               weather: .sample, news: .sample,
                               sunDay: SunCalculator.day(containing: .now, location: location),
                               timeZone: location.timeZone, unit: .auto, hasCalendarAccess: true)
        return GazetteEntry(date: .now, data: data, settings: GazetteSettings())
    }

    func getSnapshot(in context: Context, completion: @escaping (GazetteEntry) -> Void) {
        if context.isPreview && !CalendarService.hasEventAccess {
            completion(placeholder(in: context))
            return
        }
        Task { completion(await makeEntry(at: .now)) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GazetteEntry>) -> Void) {
        Task {
            let entry = await makeEntry(at: .now)
            completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(30 * 60))))
        }
    }

    private func makeEntry(at now: Date) async -> GazetteEntry {
        let global = SharedStore.global
        let settings = SharedStore.gazette
        var weather: WeatherSnapshot?
        var sunDay: SunDay?
        if let location = global.location {
            weather = await WeatherService.current(for: location)
            sunDay = SunCalculator.day(containing: now, location: location)
        }
        var news: NewsSnapshot?
        if let feed = settings.resolvedFeedURL {
            news = await NewsService.headlines(from: feed)
        }
        let events = CalendarService.events(from: Calendar.current.startOfDay(for: now), days: 7,
                                            calendarIDs: settings.calendarIDs, limit: 30)
        let reminders = settings.showReminders
            ? await CalendarService.reminders(listIDs: settings.reminderListIDs, limit: 4)
            : []
        let data = GazetteData(date: now, events: events, reminders: reminders, weather: weather, news: news,
                               sunDay: sunDay, timeZone: global.location?.timeZone ?? .current,
                               unit: global.temperatureUnit, hasCalendarAccess: CalendarService.hasEventAccess)
        return GazetteEntry(date: now, data: data, settings: settings)
    }
}

struct GazetteWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetKind.gazette, provider: GazetteProvider()) { entry in
            LookResolver(appearance: entry.settings.appearance) { look, _ in
                GazetteContent(data: entry.data, settings: entry.settings, look: look)
                    .containerBackground(for: .widget) { GazetteBackground(look: look) }
            }
        }
        .configurationDisplayName("Gazette")
        .description("Your day printed as a newspaper: events, reminders, weather and headlines.")
        .supportedFamilies([.systemLarge])
        .contentMarginsDisabled()
    }
}
