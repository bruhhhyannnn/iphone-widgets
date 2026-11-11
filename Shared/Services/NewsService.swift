import Foundation

struct Headline: Codable, Equatable, Identifiable {
    var title: String
    var link: String?
    var published: Date?
    var id: String { link ?? title }
}

struct NewsSnapshot: Codable, Equatable {
    var feedURL: String
    var fetchedAt: Date
    var headlines: [Headline]

    static let sample = NewsSnapshot(feedURL: "", fetchedAt: .now, headlines: [
        Headline(title: "City council approves new riverside park after decade-long campaign", link: nil, published: .now.addingTimeInterval(-3 * 3600)),
        Headline(title: "Researchers map the deepest coral reef ever recorded", link: nil, published: .now.addingTimeInterval(-5 * 3600)),
        Headline(title: "Night trains return to three cross-border routes this winter", link: nil, published: .now.addingTimeInterval(-2 * 3600)),
        Headline(title: "Local bakery wins national award for its rye loaf", link: nil, published: .now.addingTimeInterval(-7 * 3600)),
        Headline(title: "Space agency confirms date for next lunar lander test", link: nil, published: .now.addingTimeInterval(-9 * 3600)),
        Headline(title: "Museum reopens its glass pavilion after restoration", link: nil, published: .now.addingTimeInterval(-11 * 3600)),
    ])
}

enum NewsService {
    static func headlines(from feedURL: URL, maxAge: TimeInterval = 45 * 60) async -> NewsSnapshot? {
        let cached: NewsSnapshot? = SharedStore.load(SharedStore.Key.news, default: nil)
        if let cached, cached.feedURL == feedURL.absoluteString,
           Date().timeIntervalSince(cached.fetchedAt) < maxAge {
            return cached
        }
        if let fresh = try? await fetch(feedURL) {
            SharedStore.save(fresh, SharedStore.Key.news)
            return fresh
        }
        return cached?.feedURL == feedURL.absoluteString ? cached : nil
    }

    static func cached(for feedURL: URL?) -> NewsSnapshot? {
        guard let feedURL else { return nil }
        let cached: NewsSnapshot? = SharedStore.load(SharedStore.Key.news, default: nil)
        return cached?.feedURL == feedURL.absoluteString ? cached : nil
    }

    static func fetch(_ feedURL: URL) async throws -> NewsSnapshot {
        var request = URLRequest(url: feedURL)
        request.timeoutInterval = 15
        request.setValue("Mozilla/5.0 (iPhone) Glassboard", forHTTPHeaderField: "User-Agent")
        let (data, _) = try await URLSession.shared.data(for: request)
        let parser = FeedParser(data: data)
        let items = parser.parse()
        return NewsSnapshot(feedURL: feedURL.absoluteString, fetchedAt: .now, headlines: Array(items.prefix(12)))
    }
}

/// Minimal RSS 2.0 / Atom parser: title, link and date of each item.
private final class FeedParser: NSObject, XMLParserDelegate {
    private let data: Data
    private var items: [Headline] = []
    private var inItem = false
    private var currentElement = ""
    private var title = ""
    private var link = ""
    private var dateText = ""

    init(data: Data) { self.data = data }

    func parse() -> [Headline] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return items
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        let name = elementName.lowercased()
        if name == "item" || name == "entry" {
            inItem = true
            title = ""; link = ""; dateText = ""
        }
        currentElement = name
        if inItem, name == "link", let href = attributeDict["href"],
           link.isEmpty || attributeDict["rel"] == "alternate" {
            link = href
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard inItem else { return }
        switch currentElement {
        case "title": title += string
        case "link": link += string
        case "pubdate", "published", "updated", "dc:date": dateText += string
        default: break
        }
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        guard inItem, currentElement == "title", let text = String(data: CDATABlock, encoding: .utf8) else { return }
        title += text
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let name = elementName.lowercased()
        if name == "item" || name == "entry" {
            let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleanTitle.isEmpty {
                let cleanLink = link.trimmingCharacters(in: .whitespacesAndNewlines)
                items.append(Headline(title: cleanTitle,
                                      link: cleanLink.isEmpty ? nil : cleanLink,
                                      published: Self.parseDate(dateText.trimmingCharacters(in: .whitespacesAndNewlines))))
            }
            inItem = false
        }
        currentElement = ""
    }

    private static let rfc822: [DateFormatter] = ["EEE, dd MMM yyyy HH:mm:ss zzz", "EEE, dd MMM yyyy HH:mm:ss Z", "dd MMM yyyy HH:mm:ss zzz"].map {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = $0
        return f
    }

    private static func parseDate(_ text: String) -> Date? {
        guard !text.isEmpty else { return nil }
        for formatter in rfc822 {
            if let date = formatter.date(from: text) { return date }
        }
        let iso = ISO8601DateFormatter()
        if let date = iso.date(from: text) { return date }
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return iso.date(from: text)
    }
}
