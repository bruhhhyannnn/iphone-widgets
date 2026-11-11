import SwiftUI
import WidgetKit

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var showLocation = false
    @State private var showHelp = false

    var body: some View {
        @Bindable var model = model
        List {
            Section("Place") {
                Button {
                    showLocation = true
                } label: {
                    LabeledContent {
                        Text(model.global.location?.name ?? "Not set")
                    } label: {
                        Label("Location", systemImage: "location")
                    }
                }
                .foregroundStyle(Color.primary)
                Picker(selection: $model.global.temperatureUnit) {
                    ForEach(TemperatureUnit.allCases) { Text($0.label).tag($0) }
                } label: {
                    Label("Temperature", systemImage: "thermometer.medium")
                }
            }

            Section("Access") {
                accessRow("Calendar", symbol: "calendar", granted: model.hasCalendarAccess) {
                    Task { await model.requestCalendarAccess() }
                }
                accessRow("Reminders", symbol: "checklist", granted: model.hasReminderAccess) {
                    Task { await model.requestReminderAccess() }
                }
            }

            Section {
                Picker(selection: $model.global.appTheme) {
                    Text("System").tag(Appearance.auto)
                    Text("Light").tag(Appearance.light)
                    Text("Dark").tag(Appearance.dark)
                } label: {
                    Label("App theme", systemImage: "circle.lefthalf.filled")
                }
            } header: {
                Text("Appearance")
            }

            Section {
                Toggle(isOn: $model.global.launchThroughApp) {
                    Label("Open apps through Glassboard", systemImage: "arrow.uturn.right")
                }
                .tint(.brand)
            } header: {
                Text("Launcher")
            } footer: {
                Text("Turn this on if tapping a Launcher icon doesn't open its app. Glassboard opens briefly and passes you along.")
            }

            Section {
                Button {
                    model.reloadAllWidgets()
                    Task { await model.refreshData(force: true) }
                } label: {
                    Label("Refresh all widgets", systemImage: "arrow.clockwise")
                }
                Button {
                    showHelp = true
                } label: {
                    Label("How to add widgets", systemImage: "questionmark.circle")
                }
            }

            Section {
                LabeledContent("Shared with widgets", value: AppGroup.isShared ? "Yes" : "No")
                if let identifier = AppGroup.identifier {
                    LabeledContent("App Group", value: identifier)
                        .font(.footnote)
                }
                if let fetched = model.weather?.fetchedAt {
                    LabeledContent("Weather updated", value: fetched.formatted(date: .omitted, time: .shortened))
                }
                LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")
            } header: {
                Text("Diagnostics")
            } footer: {
                if !AppGroup.isShared {
                    Text("Widgets can't read your settings because the App Group isn't available. Reinstall with Sideloadly or AltStore and keep app groups enabled.")
                } else {
                    Text("Weather by Open-Meteo.com. Everything is free, forever.")
                }
            }
        }
        .navigationTitle("Settings")
        .sheet(isPresented: $showLocation) { LocationPickerView() }
        .sheet(isPresented: $showHelp) { HelpView() }
    }

    private func accessRow(_ title: String, symbol: String, granted: Bool, request: @escaping () -> Void) -> some View {
        HStack {
            Label(title, systemImage: symbol)
            Spacer()
            if granted {
                Text("Allowed").foregroundStyle(.secondary)
            } else {
                Button("Allow", action: request)
                    .buttonStyle(.glassProminent)
                    .tint(.brand)
            }
        }
    }
}
