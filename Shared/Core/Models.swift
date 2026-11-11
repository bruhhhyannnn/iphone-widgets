import SwiftUI

// MARK: - Shared enums

enum Appearance: String, Codable, CaseIterable, Identifiable {
    case auto, light, dark
    var id: String { rawValue }
    var label: String {
        switch self {
        case .auto: "Auto"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}

enum TemperatureUnit: String, Codable, CaseIterable, Identifiable {
    case auto, celsius, fahrenheit
    var id: String { rawValue }
    var label: String {
        switch self {
        case .auto: "Auto"
        case .celsius: "°C"
        case .fahrenheit: "°F"
        }
    }
    var usesFahrenheit: Bool {
        switch self {
        case .auto: Locale.current.measurementSystem == .us
        case .celsius: false
        case .fahrenheit: true
        }
    }
}

enum Accent: String, Codable, CaseIterable, Identifiable {
    case teal, red, orange, green, blue, purple, pink, graphite
    var id: String { rawValue }

    var color: Color {
        switch self {
        case .teal: Color(hex: 0x1A9C98)
        case .red: Color(hex: 0xEE3B30)
        case .orange: Color(hex: 0xE38A12)
        case .green: Color(hex: 0x5BA21A)
        case .blue: Color(hex: 0x2F6FE4)
        case .purple: Color(hex: 0x7B5CE5)
        case .pink: Color(hex: 0xE2487F)
        case .graphite: Color(hex: 0x3A3B3F)
        }
    }

    /// Graphite is too dark to read on a dark widget, so it lightens there.
    func color(on look: WidgetLook) -> Color {
        switch look {
        case .glass: .white
        case .dark where self == .graphite: Color(hex: 0xC7C7CC)
        default: color
        }
    }
}

// MARK: - Location

struct SavedLocation: Codable, Equatable {
    var name: String
    var latitude: Double
    var longitude: Double
    var timeZoneID: String?

    var timeZone: TimeZone {
        timeZoneID.flatMap(TimeZone.init(identifier:)) ?? .current
    }

    static let sample = SavedLocation(name: "Lisbon", latitude: 38.7223, longitude: -9.1393, timeZoneID: "Europe/Lisbon")
}

// MARK: - Settings

struct GlobalSettings: Codable, Equatable {
    var location: SavedLocation?
    var temperatureUnit: TemperatureUnit = .auto
    var appTheme: Appearance = .dark
    /// Open launcher apps by bouncing through Glassboard (slower, but works for every URL).
    var launchThroughApp: Bool = false
}

struct DaylightSettings: Codable, Equatable {
    var showCountdown: Bool = true
    var showStars: Bool = true
}

enum AgendaMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case next, week, sky
    var id: String { rawValue }
    var label: String {
        switch self {
        case .next: "Now"
        case .week: "Week"
        case .sky: "Sky"
        }
    }
    var symbol: String {
        switch self {
        case .next: "bolt.fill"
        case .week: "calendar"
        case .sky: "cloud.sun.fill"
        }
    }
}

struct AgendaSettings: Codable, Equatable {
    var accent: Accent = .teal
    var appearance: Appearance = .auto
    var mode: AgendaMode = .next
    var calendarIDs: [String] = []
}

enum GazetteTypeface: String, Codable, CaseIterable, Identifiable {
    case newYork, baskerville, didot, bodoni, georgia
    var id: String { rawValue }
    var label: String {
        switch self {
        case .newYork: "New York"
        case .baskerville: "Baskerville"
        case .didot: "Didot"
        case .bodoni: "Bodoni"
        case .georgia: "Georgia"
        }
    }
    /// Font family name of the built-in iOS font (nil = the system serif, New York).
    var familyName: String? {
        switch self {
        case .newYork: nil
        case .baskerville: "Baskerville"
        case .didot: "Didot"
        case .bodoni: "Bodoni 72"
        case .georgia: "Georgia"
        }
    }

    func font(_ size: CGFloat, weight: Font.Weight = .regular, italic: Bool = false) -> Font {
        var font: Font
        if let familyName {
            font = .custom(familyName, size: size).weight(weight)
        } else {
            font = .system(size: size, weight: weight, design: .serif)
        }
        if italic { font = font.italic() }
        return font
    }
}

enum NewsSource: String, Codable, CaseIterable, Identifiable {
    case none, bbcWorld, bbcTech, appleNewsroom, theVerge, hackerNews, custom
    var id: String { rawValue }
    var label: String {
        switch self {
        case .none: "No news"
        case .bbcWorld: "BBC World"
        case .bbcTech: "BBC Tech"
        case .appleNewsroom: "Apple Newsroom"
        case .theVerge: "The Verge"
        case .hackerNews: "Hacker News"
        case .custom: "Custom feed"
        }
    }
    var shortLabel: String {
        switch self {
        case .appleNewsroom: "Apple"
        case .custom: "Your feed"
        default: label
        }
    }
    var feedURL: URL? {
        switch self {
        case .none, .custom: nil
        case .bbcWorld: URL(string: "https://feeds.bbci.co.uk/news/world/rss.xml")
        case .bbcTech: URL(string: "https://feeds.bbci.co.uk/news/technology/rss.xml")
        case .appleNewsroom: URL(string: "https://www.apple.com/newsroom/rss-feed.rss")
        case .theVerge: URL(string: "https://www.theverge.com/rss/index.xml")
        case .hackerNews: URL(string: "https://hnrss.org/frontpage")
        }
    }
}

struct GazetteSettings: Codable, Equatable {
    var typeface: GazetteTypeface = .newYork
    var news: NewsSource = .bbcWorld
    var customFeedURL: String = ""
    var appearance: Appearance = .auto
    var calendarIDs: [String] = []
    var reminderListIDs: [String] = []
    var showReminders: Bool = true

    var resolvedFeedURL: URL? {
        if news == .custom {
            let trimmed = customFeedURL.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : URL(string: trimmed)
        }
        return news.feedURL
    }
}

struct MonthSettings: Codable, Equatable {
    var accent: Accent = .red
    var appearance: Appearance = .auto
    var monthOffset: Int = 0
    var showEventDots: Bool = true
}

struct FlipSettings: Codable, Equatable {
    var accent: Accent = .orange
    var appearance: Appearance = .auto
    var use24Hour: Bool = false
    var showDate: Bool = true
}

// MARK: - Launcher

enum IconStyle: String, Codable, CaseIterable, Identifiable {
    case color, tinted, mono, ghost
    var id: String { rawValue }
    var label: String {
        switch self {
        case .color: "Color"
        case .tinted: "Tinted"
        case .mono: "Mono"
        case .ghost: "Ghost"
        }
    }
}

enum DrawerScene: String, Codable, CaseIterable, Identifiable {
    case plain, retro, aurora, dusk, ocean, ember, graphite, photo
    var id: String { rawValue }
    var label: String {
        switch self {
        case .plain: "Plain"
        case .retro: "Retro"
        case .aurora: "Aurora"
        case .dusk: "Dusk"
        case .ocean: "Ocean"
        case .ember: "Ember"
        case .graphite: "Graphite"
        case .photo: "Photo"
        }
    }
}

struct LauncherApp: Codable, Identifiable, Equatable, Hashable {
    var id: UUID = UUID()
    var name: String
    /// What the icon opens: a URL scheme (`spotify://`), a website, or a Shortcut link.
    var url: String
    /// File name of the downloaded icon inside the shared container (Icons/…png).
    var iconFile: String?
    /// SF Symbol used by the Mono/Ghost styles or when there is no icon.
    var symbol: String = "app.fill"
}

struct Drawer: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String = "My Drawer"
    var apps: [LauncherApp] = []
    var style: IconStyle = .color
    var scene: DrawerScene = .retro
    var tint: Accent = .orange
    var appearance: Appearance = .dark
    var showLabels: Bool = false
    /// File name of the photo background (Backgrounds/…jpg) when scene == .photo.
    var photoFile: String?
}

struct DrawerList: Codable, Equatable {
    var drawers: [Drawer] = [Drawer()]
}

// MARK: - Widget kinds

enum WidgetKind {
    static let daylight = "GlassboardDaylight"
    static let agenda = "GlassboardAgenda"
    static let gazette = "GlassboardGazette"
    static let month = "GlassboardMonth"
    static let flip = "GlassboardFlip"
    static let launcher = "GlassboardLauncher"
}
