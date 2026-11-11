import SwiftUI
import WidgetKit

// MARK: - Daylight

struct DaylightEntry: TimelineEntry {
    let date: Date
    let data: DaylightData
    let settings: DaylightSettings
}

struct DaylightProvider: TimelineProvider {
    func placeholder(in context: Context) -> DaylightEntry {
        DaylightEntry(date: .now, data: .make(at: .now, location: .sample), settings: DaylightSettings())
    }

    func getSnapshot(in context: Context, completion: @escaping (DaylightEntry) -> Void) {
        let location = SharedStore.global.location ?? .sample
        completion(DaylightEntry(date: .now, data: .make(at: .now, location: location), settings: SharedStore.daylight))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DaylightEntry>) -> Void) {
        let location = SharedStore.global.location
        let settings = SharedStore.daylight
        let now = Date()
        let entries = (0..<24).map { i -> DaylightEntry in
            let date = now.addingTimeInterval(Double(i) * 600)
            return DaylightEntry(date: date, data: .make(at: date, location: location), settings: settings)
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct DaylightWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetKind.daylight, provider: DaylightProvider()) { entry in
            LookResolver(appearance: .dark) { look, family in
                DaylightContent(data: entry.data, settings: entry.settings, family: family, look: look)
                    .containerBackground(for: .widget) {
                        DaylightBackground(data: entry.data, look: look, showStars: entry.settings.showStars)
                    }
            }
        }
        .configurationDisplayName("Daylight")
        .description("Sunrise, sunset and when the light turns golden.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

// MARK: - Flip clock

struct FlipEntry: TimelineEntry {
    let date: Date
    let settings: FlipSettings
}

struct FlipProvider: TimelineProvider {
    func placeholder(in context: Context) -> FlipEntry { FlipEntry(date: .now, settings: FlipSettings()) }

    func getSnapshot(in context: Context, completion: @escaping (FlipEntry) -> Void) {
        completion(FlipEntry(date: .now, settings: SharedStore.flip))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FlipEntry>) -> Void) {
        let settings = SharedStore.flip
        let now = Date()
        let minuteStart = Calendar.current.dateInterval(of: .minute, for: now)?.start ?? now
        let entries = (0..<60).map { FlipEntry(date: minuteStart.addingTimeInterval(Double($0) * 60), settings: settings) }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct FlipClockWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetKind.flip, provider: FlipProvider()) { entry in
            LookResolver(appearance: entry.settings.appearance) { look, family in
                FlipClockContent(date: entry.date, settings: entry.settings, family: family, look: look)
                    .containerBackground(for: .widget) { FlipClockBackground(look: look) }
            }
        }
        .configurationDisplayName("Flip Clock")
        .description("A split-flap clock.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

// MARK: - Month

struct MonthEntry: TimelineEntry {
    let date: Date
    let settings: MonthSettings
    let eventDays: Set<Date>
}

struct MonthProvider: TimelineProvider {
    func placeholder(in context: Context) -> MonthEntry {
        MonthEntry(date: .now, settings: MonthSettings(), eventDays: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (MonthEntry) -> Void) {
        completion(makeEntry(at: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MonthEntry>) -> Void) {
        let now = Date()
        let tomorrow = Calendar.current.startOfDay(for: now).addingTimeInterval(86400 + 60)
        completion(Timeline(entries: [makeEntry(at: now)], policy: .after(tomorrow)))
    }

    private func makeEntry(at date: Date) -> MonthEntry {
        let settings = SharedStore.month
        var eventDays = Set<Date>()
        if settings.showEventDots {
            let cal = Calendar.current
            let thisMonth = cal.date(from: cal.dateComponents([.year, .month], from: date)) ?? date
            if let start = cal.date(byAdding: .month, value: settings.monthOffset, to: thisMonth),
               let end = cal.date(byAdding: .month, value: 2, to: start) {
                eventDays = CalendarService.daysWithEvents(in: DateInterval(start: start, end: end))
            }
        }
        return MonthEntry(date: date, settings: settings, eventDays: eventDays)
    }
}

struct MonthWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetKind.month, provider: MonthProvider()) { entry in
            LookResolver(appearance: entry.settings.appearance) { look, family in
                MonthContent(today: entry.date, settings: entry.settings, eventDays: entry.eventDays,
                             family: family, look: look, onShift: nil)
                    .containerBackground(for: .widget) { MonthBackground(look: look) }
            }
        }
        .configurationDisplayName("Month")
        .description("The month at a glance. Tap the arrows to flip through months.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}
