import SwiftUI
import WidgetKit

@main
struct GlassboardWidgetsBundle: WidgetBundle {
    var body: some Widget {
        DaylightWidget()
        AgendaWidget()
        GazetteWidget()
        MonthWidget()
        FlipClockWidget()
        LauncherWidget()
    }
}

/// Works out light / dark / glass for the current widget and hands it to the content.
struct LookResolver<Content: View>: View {
    var appearance: Appearance
    @ViewBuilder var content: (WidgetLook, WidgetFamily) -> Content

    @Environment(\.colorScheme) private var scheme
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.widgetFamily) private var family

    var body: some View {
        content(WidgetLook.resolve(appearance, scheme: scheme, renderingMode: renderingMode), family)
    }
}
