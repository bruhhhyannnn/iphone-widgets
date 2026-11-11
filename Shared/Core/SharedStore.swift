import Foundation

/// JSON-in-UserDefaults storage shared by the app and the widgets through the App Group.
///
/// Loading merges the stored JSON over the type's defaults, so adding a new setting
/// in a later version keeps everything the user already chose.
enum SharedStore {
    static func load<T: Codable>(_ key: String, default fallback: T) -> T {
        guard let data = AppGroup.defaults.data(forKey: key) else { return fallback }
        let decoder = JSONDecoder()
        if let value = try? decoder.decode(T.self, from: data) { return value }
        // Fill in keys that did not exist when the value was saved.
        guard let defaultsData = try? JSONEncoder().encode(fallback),
              var merged = (try? JSONSerialization.jsonObject(with: defaultsData)) as? [String: Any],
              let stored = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        else { return fallback }
        merged.merge(stored) { _, new in new }
        guard let mergedData = try? JSONSerialization.data(withJSONObject: merged),
              let value = try? decoder.decode(T.self, from: mergedData)
        else { return fallback }
        return value
    }

    static func save<T: Codable>(_ value: T, _ key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        AppGroup.defaults.set(data, forKey: key)
    }
}

extension SharedStore {
    enum Key {
        static let global = "settings.global"
        static let daylight = "settings.daylight"
        static let agenda = "settings.agenda"
        static let gazette = "settings.gazette"
        static let month = "settings.month"
        static let flip = "settings.flip"
        static let drawers = "settings.drawers"
        static let weather = "cache.weather"
        static let news = "cache.news"
    }

    static var global: GlobalSettings {
        get { load(Key.global, default: GlobalSettings()) }
        set { save(newValue, Key.global) }
    }
    static var daylight: DaylightSettings {
        get { load(Key.daylight, default: DaylightSettings()) }
        set { save(newValue, Key.daylight) }
    }
    static var agenda: AgendaSettings {
        get { load(Key.agenda, default: AgendaSettings()) }
        set { save(newValue, Key.agenda) }
    }
    static var gazette: GazetteSettings {
        get { load(Key.gazette, default: GazetteSettings()) }
        set { save(newValue, Key.gazette) }
    }
    static var month: MonthSettings {
        get { load(Key.month, default: MonthSettings()) }
        set { save(newValue, Key.month) }
    }
    static var flip: FlipSettings {
        get { load(Key.flip, default: FlipSettings()) }
        set { save(newValue, Key.flip) }
    }
    static var drawers: DrawerList {
        get { load(Key.drawers, default: DrawerList()) }
        set { save(newValue, Key.drawers) }
    }
}
