import EventKit
import UIKit

struct AgendaEvent: Codable, Equatable, Identifiable {
    var id: String
    var title: String
    var location: String?
    var start: Date
    var end: Date
    var isAllDay: Bool
    var colorHex: UInt32?

    static func samples(now: Date = .now) -> [AgendaEvent] {
        let cal = Calendar.current
        let tomorrow = cal.startOfDay(for: now).addingTimeInterval(86400)
        func at(_ dayOffset: Int, _ hour: Int, _ minute: Int = 0) -> Date {
            cal.date(bySettingHour: hour, minute: minute, second: 0, of: tomorrow.addingTimeInterval(Double(dayOffset) * 86400)) ?? now
        }
        return [
            AgendaEvent(id: "s1", title: "Design review", location: "Room 4", start: at(0, 9), end: at(0, 10), isAllDay: false, colorHex: 0x1A9C98),
            AgendaEvent(id: "s2", title: "Lunch with Maya", location: "Rosa Café", start: at(0, 12, 30), end: at(0, 13, 30), isAllDay: false, colorHex: 0xE38A12),
            AgendaEvent(id: "s3", title: "Climbing", location: nil, start: at(1, 18), end: at(1, 20), isAllDay: false, colorHex: 0x5BA21A),
            AgendaEvent(id: "s4", title: "Dad's birthday", location: nil, start: at(3, 0), end: at(4, 0), isAllDay: true, colorHex: 0xE2487F),
        ]
    }
}

struct ReminderItem: Codable, Equatable, Identifiable {
    var id: String
    var title: String
    var due: Date?
    var dueHasTime: Bool

    static let samples: [ReminderItem] = [
        ReminderItem(id: "r1", title: "Pay the electricity bill", due: Calendar.current.startOfDay(for: .now), dueHasTime: false),
        ReminderItem(id: "r2", title: "Book dentist", due: nil, dueHasTime: false),
    ]
}

struct CalendarInfo: Identifiable, Hashable {
    var id: String
    var title: String
    var source: String
    var colorHex: UInt32
}

enum CalendarService {
    private static let store = EKEventStore()

    static var hasEventAccess: Bool { EKEventStore.authorizationStatus(for: .event) == .fullAccess }
    static var hasReminderAccess: Bool { EKEventStore.authorizationStatus(for: .reminder) == .fullAccess }

    static func requestEventAccess() async -> Bool {
        let granted = (try? await store.requestFullAccessToEvents()) ?? false
        if granted { store.reset() }
        return granted
    }

    static func requestReminderAccess() async -> Bool {
        let granted = (try? await store.requestFullAccessToReminders()) ?? false
        if granted { store.reset() }
        return granted
    }

    static func calendars() -> [CalendarInfo] {
        guard hasEventAccess else { return [] }
        return store.calendars(for: .event).map(info).sorted { ($0.source, $0.title) < ($1.source, $1.title) }
    }

    static func reminderLists() -> [CalendarInfo] {
        guard hasReminderAccess else { return [] }
        return store.calendars(for: .reminder).map(info).sorted { ($0.source, $0.title) < ($1.source, $1.title) }
    }

    /// Events overlapping the next `days` days, sorted by start time.
    static func events(from start: Date = .now, days: Int, calendarIDs: [String] = [], limit: Int = 20) -> [AgendaEvent] {
        guard hasEventAccess else { return [] }
        let end = start.addingTimeInterval(Double(days) * 86400)
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: selected(calendarIDs, type: .event))
        return store.events(matching: predicate)
            .filter { $0.status != .canceled }
            .sorted { $0.startDate < $1.startDate }
            .prefix(limit)
            .map { event in
                AgendaEvent(
                    id: event.eventIdentifier ?? UUID().uuidString,
                    title: event.title ?? "Untitled",
                    location: event.location.flatMap { $0.isEmpty ? nil : $0.components(separatedBy: "\n").first },
                    start: event.startDate,
                    end: event.endDate,
                    isAllDay: event.isAllDay,
                    colorHex: event.calendar.map { hex($0.cgColor) }
                )
            }
    }

    /// Start-of-day dates that have at least one event, for the month dots.
    static func daysWithEvents(in interval: DateInterval, calendarIDs: [String] = []) -> Set<Date> {
        guard hasEventAccess else { return [] }
        let predicate = store.predicateForEvents(withStart: interval.start, end: interval.end, calendars: selected(calendarIDs, type: .event))
        let cal = Calendar.current
        var days = Set<Date>()
        for event in store.events(matching: predicate) where event.status != .canceled {
            var day = cal.startOfDay(for: max(event.startDate, interval.start))
            let last = min(event.endDate.addingTimeInterval(-1), interval.end)
            while day <= last {
                days.insert(day)
                guard let next = cal.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
            }
        }
        return days
    }

    /// Incomplete reminders: ones with a due date first (soonest first), then the rest.
    static func reminders(listIDs: [String] = [], limit: Int = 6) async -> [ReminderItem] {
        guard hasReminderAccess else { return [] }
        let predicate = store.predicateForIncompleteReminders(
            withDueDateStarting: nil, ending: nil, calendars: selected(listIDs, type: .reminder))
        return await withCheckedContinuation { continuation in
            store.fetchReminders(matching: predicate) { reminders in
                let items: [ReminderItem] = (reminders ?? []).map { reminder in
                    let components = reminder.dueDateComponents
                    let due = components.flatMap { Calendar.current.date(from: $0) }
                    return ReminderItem(
                        id: reminder.calendarItemIdentifier,
                        title: reminder.title ?? "Untitled",
                        due: due,
                        dueHasTime: components?.hour != nil
                    )
                }
                let sorted = items.sorted { a, b in
                    switch (a.due, b.due) {
                    case let (x?, y?): return x < y
                    case (.some, nil): return true
                    case (nil, .some): return false
                    case (nil, nil): return a.title < b.title
                    }
                }
                continuation.resume(returning: Array(sorted.prefix(limit)))
            }
        }
    }

    // MARK: Helpers

    private static func selected(_ ids: [String], type: EKEntityType) -> [EKCalendar]? {
        guard !ids.isEmpty else { return nil }
        let matches = store.calendars(for: type).filter { ids.contains($0.calendarIdentifier) }
        return matches.isEmpty ? nil : matches
    }

    private static func info(_ calendar: EKCalendar) -> CalendarInfo {
        CalendarInfo(id: calendar.calendarIdentifier, title: calendar.title,
                     source: calendar.source?.title ?? "", colorHex: hex(calendar.cgColor))
    }

    private static func hex(_ cgColor: CGColor?) -> UInt32 {
        guard let cgColor else { return 0x8E8E93 }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(cgColor: cgColor).getRed(&r, green: &g, blue: &b, alpha: &a)
        func byte(_ v: CGFloat) -> UInt32 { UInt32(max(0, min(255, (v * 255).rounded()))) }
        return byte(r) << 16 | byte(g) << 8 | byte(b)
    }
}
