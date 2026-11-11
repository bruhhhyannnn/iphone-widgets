import UIKit

/// Apps with a known URL scheme. You can always add any app by hand with its own link.
struct CatalogApp: Identifiable, Hashable {
    var name: String
    var url: String
    var symbol: String
    /// Name to look up on the App Store for the icon.
    var storeTerm: String
    var id: String { name }

    init(_ name: String, _ url: String, _ symbol: String, store: String? = nil) {
        self.name = name
        self.url = url
        self.symbol = symbol
        self.storeTerm = store ?? name
    }
}

enum AppCatalog {
    static let apps: [CatalogApp] = [
        // Apple
        CatalogApp("Messages", "sms://", "message.fill", store: "Apple Messages"),
        CatalogApp("Mail", "message://", "envelope.fill", store: "Apple Mail"),
        CatalogApp("Safari", "x-web-search://", "safari.fill", store: "Safari browser"),
        CatalogApp("Maps", "maps://", "map.fill", store: "Apple Maps"),
        CatalogApp("Music", "music://", "music.note", store: "Apple Music"),
        CatalogApp("Photos", "photos-redirect://", "photo.fill", store: "Apple Photos"),
        CatalogApp("Calendar", "calshow://", "calendar", store: "Apple Calendar"),
        CatalogApp("Notes", "mobilenotes://", "note.text", store: "Apple Notes"),
        CatalogApp("Reminders", "x-apple-reminderkit://", "checklist", store: "Apple Reminders"),
        CatalogApp("Weather", "weather://", "cloud.sun.fill", store: "Apple Weather"),
        CatalogApp("Clock", "clock-alarm://", "alarm.fill", store: "Apple Clock"),
        CatalogApp("Podcasts", "podcasts://", "mic.fill", store: "Apple Podcasts"),
        CatalogApp("Books", "ibooks://", "book.fill", store: "Apple Books"),
        CatalogApp("TV", "videos://", "tv.fill", store: "Apple TV"),
        CatalogApp("Wallet", "shoebox://", "wallet.pass.fill", store: "Apple Wallet"),
        CatalogApp("Files", "shareddocuments://", "folder.fill", store: "Apple Files"),
        CatalogApp("Shortcuts", "shortcuts://", "square.2.layers.3d.fill", store: "Apple Shortcuts"),
        CatalogApp("Health", "x-apple-health://", "heart.fill", store: "Apple Health"),
        CatalogApp("Find My", "findmy://", "location.circle.fill", store: "Apple Find My"),
        CatalogApp("Home", "com.apple.home://", "house.fill", store: "Apple Home"),
        CatalogApp("Voice Memos", "voicememos://", "waveform", store: "Apple Voice Memos"),
        CatalogApp("App Store", "itms-apps://", "bag.fill", store: "Apple Store app"),
        CatalogApp("Settings", "App-prefs:", "gearshape.fill", store: "Apple Settings"),
        // Video & music
        CatalogApp("YouTube", "youtube://", "play.rectangle.fill"),
        CatalogApp("YouTube Music", "youtubemusic://", "music.note.list"),
        CatalogApp("Spotify", "spotify://", "music.note"),
        CatalogApp("Netflix", "nflx://", "play.tv.fill"),
        CatalogApp("Disney+", "disneyplus://", "tv.fill"),
        CatalogApp("Prime Video", "aiv://", "play.tv.fill", store: "Amazon Prime Video"),
        CatalogApp("Twitch", "twitch://", "gamecontroller.fill"),
        CatalogApp("Shazam", "shazam://", "shazam.logo.fill"),
        CatalogApp("VLC", "vlc://", "play.circle.fill", store: "VLC media player"),
        // Social & chat
        CatalogApp("Instagram", "instagram://", "camera.fill"),
        CatalogApp("Facebook", "fb://", "person.2.fill"),
        CatalogApp("Messenger", "fb-messenger://", "bubble.left.and.bubble.right.fill"),
        CatalogApp("WhatsApp", "whatsapp://", "phone.bubble.fill"),
        CatalogApp("Telegram", "tg://", "paperplane.fill"),
        CatalogApp("Viber", "viber://", "phone.fill"),
        CatalogApp("Signal", "sgnl://", "lock.shield.fill", store: "Signal Private Messenger"),
        CatalogApp("Discord", "discord://", "headphones"),
        CatalogApp("X", "twitter://", "at", store: "X Twitter"),
        CatalogApp("Threads", "barcelona://", "at.circle.fill", store: "Threads Instagram"),
        CatalogApp("TikTok", "snssdk1233://", "music.note.tv.fill"),
        CatalogApp("Snapchat", "snapchat://", "camera.viewfinder"),
        CatalogApp("Reddit", "reddit://", "bubble.left.fill"),
        CatalogApp("Pinterest", "pinterest://", "pin.fill"),
        CatalogApp("LinkedIn", "linkedin://", "briefcase.fill"),
        CatalogApp("Line", "line://", "message.badge.fill", store: "LINE"),
        // Google & work
        CatalogApp("Gmail", "googlegmail://", "envelope.badge.fill"),
        CatalogApp("Google", "google://", "magnifyingglass", store: "Google app"),
        CatalogApp("Chrome", "googlechrome://", "globe", store: "Google Chrome"),
        CatalogApp("Google Maps", "comgooglemaps://", "map.circle.fill"),
        CatalogApp("Google Drive", "googledrive://", "externaldrive.fill"),
        CatalogApp("Google Photos", "googlephotos://", "photo.on.rectangle"),
        CatalogApp("Google Calendar", "googlecalendar://", "calendar.badge.clock"),
        CatalogApp("Outlook", "ms-outlook://", "envelope.open.fill", store: "Microsoft Outlook"),
        CatalogApp("Teams", "msteams://", "person.3.fill", store: "Microsoft Teams"),
        CatalogApp("Zoom", "zoomus://", "video.fill", store: "Zoom Workplace"),
        CatalogApp("Slack", "slack://", "number"),
        CatalogApp("Notion", "notion://", "doc.text.fill"),
        CatalogApp("Canva", "canva://", "paintpalette.fill"),
        // Getting around & money
        CatalogApp("Grab", "grab://", "car.fill"),
        CatalogApp("Uber", "uber://", "car.side.fill"),
        CatalogApp("Waze", "waze://", "car.circle.fill"),
        CatalogApp("PayPal", "paypal://", "creditcard.fill"),
        CatalogApp("Duolingo", "duolingo://", "graduationcap.fill"),
    ]

    static func search(_ text: String) -> [CatalogApp] {
        let query = text.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return apps }
        return apps.filter { $0.name.lowercased().contains(query) || $0.url.lowercased().contains(query) }
    }
}

/// Looks up app icons on the App Store (iTunes Search API, no key needed).
enum IconSearch {
    struct Result: Identifiable, Hashable {
        var name: String
        var artwork: URL
        var id: URL { artwork }
    }

    static func search(_ term: String, limit: Int = 8) async -> [Result] {
        var components = URLComponents(string: "https://itunes.apple.com/search")!
        components.queryItems = [
            URLQueryItem(name: "term", value: term),
            URLQueryItem(name: "entity", value: "software"),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "country", value: Locale.current.region?.identifier.lowercased() ?? "us"),
        ]
        guard let url = components.url,
              let result = try? await URLSession.shared.data(from: url),
              let response = try? JSONDecoder().decode(SearchResponse.self, from: result.0)
        else { return [] }
        return response.results.compactMap { item in
            guard let art = item.artworkUrl512 ?? item.artworkUrl100, let artURL = URL(string: art) else { return nil }
            return Result(name: item.trackName, artwork: artURL)
        }
    }

    /// Downloads an icon and stores it for the widget. Returns the file name.
    static func downloadIcon(from url: URL) async -> String? {
        guard let result = try? await URLSession.shared.data(from: url),
              let image = UIImage(data: result.0) else { return nil }
        return ImageStore.save(image, in: ImageStore.iconsFolder, maxPixel: 180)
    }

    /// Best-effort: first App Store result for the name.
    static func fetchIcon(for term: String) async -> String? {
        guard let first = await search(term, limit: 1).first else { return nil }
        return await downloadIcon(from: first.artwork)
    }

    private struct SearchResponse: Decodable {
        struct Item: Decodable {
            var trackName: String
            var artworkUrl512: String?
            var artworkUrl100: String?
        }
        var results: [Item]
    }
}
