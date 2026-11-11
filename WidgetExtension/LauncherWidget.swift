import SwiftUI
import WidgetKit

struct LauncherEntry: TimelineEntry {
    let date: Date
    let drawer: Drawer
    let icons: [UUID: UIImage]
    let photo: UIImage?
    let launchThroughApp: Bool
}

struct LauncherProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> LauncherEntry {
        var drawer = Drawer()
        drawer.style = .mono
        drawer.apps = [
            LauncherApp(name: "Music", url: "music://", symbol: "music.note"),
            LauncherApp(name: "Photos", url: "photos-redirect://", symbol: "photo.fill"),
            LauncherApp(name: "Maps", url: "maps://", symbol: "map.fill"),
            LauncherApp(name: "Mail", url: "message://", symbol: "envelope.fill"),
        ]
        return LauncherEntry(date: .now, drawer: drawer, icons: [:], photo: nil, launchThroughApp: false)
    }

    func snapshot(for configuration: SelectDrawerIntent, in context: Context) async -> LauncherEntry {
        let entry = makeEntry(for: configuration)
        return entry.drawer.apps.isEmpty && context.isPreview ? placeholder(in: context) : entry
    }

    func timeline(for configuration: SelectDrawerIntent, in context: Context) async -> Timeline<LauncherEntry> {
        // The app reloads this widget whenever a drawer changes.
        Timeline(entries: [makeEntry(for: configuration)], policy: .never)
    }

    private func makeEntry(for configuration: SelectDrawerIntent) -> LauncherEntry {
        let drawers = SharedStore.drawers.drawers
        let drawer = drawers.first { $0.id.uuidString == configuration.drawer?.id } ?? drawers.first ?? Drawer()
        var icons: [UUID: UIImage] = [:]
        for app in drawer.apps.prefix(16) {
            if let image = ImageStore.image(app.iconFile, in: ImageStore.iconsFolder, maxPixel: 160) {
                icons[app.id] = image
            }
        }
        let photo = drawer.scene == .photo
            ? ImageStore.image(drawer.photoFile, in: ImageStore.backgroundsFolder, maxPixel: 700)
            : nil
        return LauncherEntry(date: .now, drawer: drawer, icons: icons, photo: photo,
                             launchThroughApp: SharedStore.global.launchThroughApp)
    }
}

struct LauncherWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: WidgetKind.launcher, intent: SelectDrawerIntent.self, provider: LauncherProvider()) { entry in
            LookResolver(appearance: entry.drawer.appearance) { look, family in
                LauncherContent(drawer: entry.drawer, icons: entry.icons, family: family, look: look,
                                launchThroughApp: entry.launchThroughApp)
                    .containerBackground(for: .widget) {
                        LauncherBackground(drawer: entry.drawer, photo: entry.photo, look: look)
                    }
            }
        }
        .configurationDisplayName("Launcher")
        .description("A drawer of your apps. Long-press the widget to pick which drawer it shows.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}
