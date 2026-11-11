import WidgetKit
import SwiftUI

struct PingEntry: TimelineEntry { let date: Date }

struct PingProvider: TimelineProvider {
    func placeholder(in context: Context) -> PingEntry { PingEntry(date: .now) }
    func getSnapshot(in context: Context, completion: @escaping (PingEntry) -> Void) { completion(PingEntry(date: .now)) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<PingEntry>) -> Void) {
        completion(Timeline(entries: [PingEntry(date: .now)], policy: .never))
    }
}

struct PingWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Ping", provider: PingProvider()) { entry in
            Text(entry.date, style: .time).containerBackground(.fill, for: .widget)
        }
        .configurationDisplayName("Ping")
    }
}

@main
struct GlassboardWidgetsBundle: WidgetBundle {
    var body: some Widget { PingWidget() }
}
