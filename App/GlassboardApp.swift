import SwiftUI

@main
struct GlassboardApp: App {
    @State private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .tint(.brand)
                .preferredColorScheme(model.global.appTheme.colorScheme)
                .onOpenURL { model.handle($0) }
                .task { await model.refreshData() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        model.reloadFromStore()
                        Task { await model.refreshData() }
                    }
                }
        }
    }
}

struct RootView: View {
    enum TabID: Hashable { case widgets, launcher, settings }
    @State private var tab: TabID = .widgets

    var body: some View {
        TabView(selection: $tab) {
            Tab("Widgets", systemImage: "sparkles", value: TabID.widgets) {
                NavigationStack { WidgetGalleryView() }
            }
            Tab("Launcher", systemImage: "square.grid.3x3.fill", value: TabID.launcher) {
                NavigationStack { LauncherHomeView() }
            }
            Tab("Settings", systemImage: "gearshape.fill", value: TabID.settings) {
                NavigationStack { SettingsView() }
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
    }
}
