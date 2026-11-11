import SwiftUI
import WidgetKit

struct WidgetGalleryView: View {
    @Environment(AppModel.self) private var model
    @State private var showHelp = false

    var body: some View {
        @Bindable var model = model
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 12) {
                    Text("Preview in")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    GlassChips(options: WidgetLook.allCases, selection: $model.previewLook) { $0.label }
                }
                DaylightCard()
                AgendaCard()
                GazetteCard()
                MonthCard()
                FlipCard()
                Button {
                    showHelp = true
                } label: {
                    Label("How to add widgets to your Home Screen", systemImage: "questionmark.circle")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.glass)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(Color(.systemBackground))
        .navigationTitle("Widgets")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await model.refreshData(force: true) }
                } label: {
                    if model.isRefreshing { ProgressView() } else { Image(systemName: "arrow.clockwise") }
                }
            }
        }
        .refreshable { await model.refreshData(force: true) }
        .sheet(isPresented: $showHelp) { HelpView() }
    }
}

// MARK: - Daylight

struct DaylightCard: View {
    @Environment(AppModel.self) private var model
    @State private var scene: DaylightData.PreviewScene = .now
    @State private var family: WidgetFamily = .systemMedium
    @State private var showLocation = false

    var body: some View {
        @Bindable var model = model
        let data = DaylightData.preview(scene, location: model.global.location)
        let look = model.previewLook == .glass ? WidgetLook.glass : .dark
        WidgetCard(title: "Daylight", subtitle: "When the light will be good.") {
            WidgetPreview(family: family, look: look) {
                DaylightContent(data: data, settings: model.daylight, family: family, look: look)
            } background: {
                DaylightBackground(data: data, look: look, showStars: model.daylight.showStars)
            }
        } controls: {
            GlassChips(options: DaylightData.PreviewScene.allCases, selection: $scene) { $0.label }
            SettingRow(title: "Size") {
                GlassChips(options: [WidgetFamily.systemSmall, .systemMedium], selection: $family) { $0.shortLabel }
                    .fixedSize()
            }
            Toggle("Countdown to next moment", isOn: $model.daylight.showCountdown).tint(.brand)
            Toggle("Stars at night", isOn: $model.daylight.showStars).tint(.brand)
            if let location = model.global.location {
                ActionRow(title: location.name, detail: "Sunrise, sunset and the sky are worked out for this place.", button: "Change") {
                    showLocation = true
                }
            } else {
                ActionRow(title: "Set your location", detail: "Used for sunrise, sunset and the sky. Showing Lisbon until then.", button: "Set up") {
                    showLocation = true
                }
            }
        }
        .sheet(isPresented: $showLocation) { LocationPickerView() }
    }
}

// MARK: - Agenda

struct AgendaCard: View {
    @Environment(AppModel.self) private var model
    @State private var family: WidgetFamily = .systemMedium
    @State private var showCalendars = false

    var body: some View {
        @Bindable var model = model
        let look = WidgetLook.preview(model.previewLook, appearance: model.agenda.appearance)
        let data = AgendaData(date: .now, events: model.previewEvents, weather: model.previewWeather,
                              hasCalendarAccess: true, unit: model.global.temperatureUnit,
                              locationName: model.global.location?.name ?? SavedLocation.sample.name)
        WidgetCard(title: "Agenda", subtitle: "Your day at a glance.") {
            WidgetPreview(family: family, look: look) {
                AgendaContent(data: data, settings: model.agenda, family: family, look: look) { mode in
                    withAnimation(.snappy) { model.agenda.mode = mode }
                }
            } background: {
                AgendaBackground(look: look)
            }
        } controls: {
            SettingRow(title: "Size") {
                GlassChips(options: [WidgetFamily.systemSmall, .systemMedium], selection: $family) { $0.shortLabel }
                    .fixedSize()
            }
            SettingRow(title: "View") {
                GlassChips(options: AgendaMode.allCases, selection: $model.agenda.mode) { $0.label }
                    .fixedSize()
            }
            SettingRow(title: "Accent", stacked: true) { AccentPicker(selection: $model.agenda.accent) }
            SettingRow(title: "On Home Screen") {
                GlassChips(options: Appearance.allCases, selection: $model.agenda.appearance) { $0.label }
                    .fixedSize()
            }
            SettingRow(title: "Temperature") {
                GlassChips(options: TemperatureUnit.allCases, selection: $model.global.temperatureUnit) { $0.label }
                    .fixedSize()
            }
            if model.hasCalendarAccess {
                SettingRow(title: "Calendars") {
                    Button(model.agenda.calendarIDs.isEmpty ? "All" : "\(model.agenda.calendarIDs.count) chosen") {
                        showCalendars = true
                    }
                    .buttonStyle(.glass)
                }
            } else {
                ActionRow(title: "Show your calendar", detail: "Allow access so the widget shows your real events. Sample events for now.", button: "Allow") {
                    Task { await model.requestCalendarAccess() }
                }
            }
        }
        .sheet(isPresented: $showCalendars) {
            CalendarChooser(title: "Agenda calendars", calendars: CalendarService.calendars(),
                            selection: $model.agenda.calendarIDs)
        }
    }
}

// MARK: - Month

struct MonthCard: View {
    @Environment(AppModel.self) private var model
    @State private var family: WidgetFamily = .systemMedium

    var body: some View {
        @Bindable var model = model
        let look = WidgetLook.preview(model.previewLook, appearance: model.month.appearance)
        WidgetCard(title: "Month", subtitle: "The month, on a card. Arrows flip through months.") {
            WidgetPreview(family: family, look: look) {
                MonthContent(today: .now, settings: model.month, eventDays: model.eventDays, family: family, look: look) { delta in
                    withAnimation(.snappy) {
                        model.month.monthOffset = delta == 0 ? 0 : model.month.monthOffset + delta
                    }
                    model.refreshCalendar()
                }
            } background: {
                MonthBackground(look: look)
            }
        } controls: {
            SettingRow(title: "Size") {
                GlassChips(options: [WidgetFamily.systemSmall, .systemMedium], selection: $family) { $0.shortLabel }
                    .fixedSize()
            }
            SettingRow(title: "Accent", stacked: true) { AccentPicker(selection: $model.month.accent) }
            SettingRow(title: "On Home Screen") {
                GlassChips(options: Appearance.allCases, selection: $model.month.appearance) { $0.label }
                    .fixedSize()
            }
            Toggle("Dots on days with events", isOn: $model.month.showEventDots).tint(.brand)
        }
    }
}

// MARK: - Flip

struct FlipCard: View {
    @Environment(AppModel.self) private var model
    @State private var family: WidgetFamily = .systemSmall

    var body: some View {
        @Bindable var model = model
        let look = WidgetLook.preview(model.previewLook, appearance: model.flip.appearance)
        WidgetCard(title: "Flip Clock", subtitle: "A split-flap clock.") {
            TimelineView(.everyMinute) { context in
                WidgetPreview(family: family, look: look) {
                    FlipClockContent(date: context.date, settings: model.flip, family: family, look: look)
                } background: {
                    FlipClockBackground(look: look)
                }
            }
        } controls: {
            SettingRow(title: "Size") {
                GlassChips(options: [WidgetFamily.systemSmall, .systemMedium], selection: $family) { $0.shortLabel }
                    .fixedSize()
            }
            SettingRow(title: "Accent", stacked: true) { AccentPicker(selection: $model.flip.accent) }
            SettingRow(title: "On Home Screen") {
                GlassChips(options: Appearance.allCases, selection: $model.flip.appearance) { $0.label }
                    .fixedSize()
            }
            Toggle("24-hour clock", isOn: $model.flip.use24Hour).tint(.brand)
            Toggle("Show the date", isOn: $model.flip.showDate).tint(.brand)
        }
    }
}

// MARK: - Help

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Add a widget") {
                    Label("Touch and hold an empty spot on your Home Screen until the icons jiggle.", systemImage: "hand.tap")
                    Label("Tap Edit in the top corner, then Add Widget.", systemImage: "plus.circle")
                    Label("Search for Glassboard, pick a widget and a size, then tap Add Widget.", systemImage: "magnifyingglass")
                }
                Section("Liquid Glass look") {
                    Label("Touch and hold the Home Screen, tap Edit, then Customize.", systemImage: "paintbrush")
                    Label("Choose Clear (or Tinted). Every Glassboard widget switches to its glass style automatically.", systemImage: "drop")
                }
                Section("Launcher") {
                    Label("Add a Launcher widget, touch and hold it, tap Edit Widget, and pick which drawer it shows.", systemImage: "square.grid.2x2")
                    Label("If an icon doesn't open its app, turn on “Open apps through Glassboard” in Settings.", systemImage: "arrow.uturn.right")
                }
            }
            .navigationTitle("Help")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
