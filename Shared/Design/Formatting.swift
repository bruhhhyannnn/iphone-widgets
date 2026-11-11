import Foundation

enum Fmt {
    static var uses12Hour: Bool {
        DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: .current)?.contains("a") ?? true
    }

    static func string(_ date: Date, _ format: String, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.timeZone = timeZone
        formatter.dateFormat = format
        return formatter.string(from: date)
    }

    static func template(_ date: Date, _ template: String, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter.string(from: date)
    }

    /// "9:00 AM" or "09:00", following the device setting.
    static func time(_ date: Date, timeZone: TimeZone = .current) -> String {
        let parts = timeParts(date, timeZone: timeZone)
        return parts.period.map { "\(parts.main) \($0)" } ?? parts.main
    }

    /// Splits a time into the digits and the AM/PM marker so they can be styled separately.
    static func timeParts(_ date: Date, timeZone: TimeZone = .current, force24Hour: Bool = false) -> (main: String, period: String?) {
        if force24Hour || !uses12Hour {
            return (string(date, "HH:mm", timeZone: timeZone), nil)
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "h:mm"
        let main = formatter.string(from: date)
        formatter.dateFormat = "a"
        return (main, formatter.string(from: date).uppercased())
    }

    /// "13 hr 11 min", "45 min".
    static func duration(_ interval: TimeInterval) -> String {
        let totalMinutes = max(0, Int((interval / 60).rounded()))
        let hours = totalMinutes / 60, minutes = totalMinutes % 60
        if hours == 0 { return "\(minutes) min" }
        if minutes == 0 { return "\(hours) hr" }
        return "\(hours) hr \(minutes) min"
    }

    /// "Today", "Tomorrow", or the weekday name.
    static func dayLabel(_ date: Date, now: Date = .now) -> String {
        let cal = Calendar.current
        if cal.isDate(date, inSameDayAs: now) { return "Today" }
        if let tomorrow = cal.date(byAdding: .day, value: 1, to: now), cal.isDate(date, inSameDayAs: tomorrow) { return "Tomorrow" }
        if let days = cal.dateComponents([.day], from: cal.startOfDay(for: now), to: cal.startOfDay(for: date)).day, days < 7 {
            return string(date, "EEEE")
        }
        return template(date, "EEEMMMd")
    }

    /// Short relative age for headlines: "3 hr ago".
    static func age(_ date: Date?, now: Date = .now) -> String? {
        guard let date else { return nil }
        let minutes = Int(now.timeIntervalSince(date) / 60)
        if minutes < 1 { return "just now" }
        if minutes < 60 { return "\(minutes) min ago" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours) hr ago" }
        return "\(hours / 24) d ago"
    }

    static func edition(for date: Date) -> String {
        switch Calendar.current.component(.hour, from: date) {
        case 5..<12: return "Morning Edition"
        case 12..<17: return "Afternoon Edition"
        case 17..<22: return "Evening Edition"
        default: return "Late Edition"
        }
    }
}
