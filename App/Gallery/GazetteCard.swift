import SwiftUI
import WidgetKit

struct GazetteCard: View {
    @Environment(AppModel.self) private var model
    @State private var showCalendars = false
    @State private var showLists = false
    @State private var feedDraft = ""

    var body: some View {
        @Bindable var model = model
        let look = WidgetLook.preview(model.previewLook, appearance: model.gazette.appearance)
        let location = model.global.location ?? .sample
        let data = GazetteData(date: .now, events: model.previewEvents, reminders: model.previewReminders,
                               weather: model.previewWeather, news: model.previewNews,
                               sunDay: SunCalculator.day(containing: .now, location: location),
                               timeZone: location.timeZone, unit: model.global.temperatureUnit,
                               hasCalendarAccess: true)
        WidgetCard(title: "Gazette", subtitle: "Your day, printed once.") {
            WidgetPreview(family: .systemLarge, look: look) {
                GazetteContent(data: data, settings: model.gazette, look: look)
            } background: {
                GazetteBackground(look: look)
            }
        } controls: {
            SettingRow(title: "Type", stacked: true) {
                GlassChips(options: GazetteTypeface.allCases, selection: $model.gazette.typeface) { $0.label }
            }
            SettingRow(title: "News", stacked: true) {
                GlassChips(options: NewsSource.allCases, selection: $model.gazette.news) { $0.label }
            }
            if model.gazette.news == .custom {
                HStack {
                    TextField("https://example.com/feed.xml", text: $feedDraft)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .onSubmit(saveFeed)
                    Button("Save", action: saveFeed).buttonStyle(.glass)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color(.tertiarySystemBackground)))
            }
            SettingRow(title: "On Home Screen") {
                GlassChips(options: Appearance.allCases, selection: $model.gazette.appearance) { $0.label }
                    .fixedSize()
            }
            Toggle("Reminders box", isOn: $model.gazette.showReminders).tint(.brand)
            if model.hasCalendarAccess {
                SettingRow(title: "Calendars") {
                    Button(model.gazette.calendarIDs.isEmpty ? "All" : "\(model.gazette.calendarIDs.count) chosen") {
                        showCalendars = true
                    }
                    .buttonStyle(.glass)
                }
            } else {
                ActionRow(title: "Print your calendar", detail: "Allow calendar access for the lead story and the Also column.", button: "Allow") {
                    Task { await model.requestCalendarAccess() }
                }
            }
            if model.gazette.showReminders {
                if model.hasReminderAccess {
                    SettingRow(title: "Reminder lists") {
                        Button(model.gazette.reminderListIDs.isEmpty ? "All" : "\(model.gazette.reminderListIDs.count) chosen") {
                            showLists = true
                        }
                        .buttonStyle(.glass)
                    }
                } else {
                    ActionRow(title: "Show reminders", detail: "Allow access and the next ones print in the box.", button: "Allow") {
                        Task { await model.requestReminderAccess() }
                    }
                }
            }
        }
        .onAppear { feedDraft = model.gazette.customFeedURL }
        .onChange(of: model.gazette.news) { _, _ in
            Task { await model.refreshData() }
        }
        .sheet(isPresented: $showCalendars) {
            CalendarChooser(title: "Gazette calendars", calendars: CalendarService.calendars(),
                            selection: $model.gazette.calendarIDs)
        }
        .sheet(isPresented: $showLists) {
            CalendarChooser(title: "Reminder lists", calendars: CalendarService.reminderLists(),
                            selection: $model.gazette.reminderListIDs)
        }
    }

    private func saveFeed() {
        model.gazette.customFeedURL = feedDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        Task { await model.refreshData(force: true) }
    }
}

/// Multi-select list of calendars or reminder lists. An empty selection means "all".
struct CalendarChooser: View {
    var title: String
    var calendars: [CalendarInfo]
    @Binding var selection: [String]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        selection = []
                    } label: {
                        HStack {
                            Text("All").foregroundStyle(Color.primary)
                            Spacer()
                            if selection.isEmpty { Image(systemName: "checkmark").foregroundStyle(Color.brand) }
                        }
                    }
                }
                ForEach(groupedSources, id: \.self) { source in
                    Section(source) {
                        ForEach(calendars.filter { $0.source == source }) { calendar in
                            Button {
                                toggle(calendar.id)
                            } label: {
                                HStack {
                                    Circle().fill(Color(hex: calendar.colorHex)).frame(width: 12, height: 12)
                                    Text(calendar.title).foregroundStyle(Color.primary)
                                    Spacer()
                                    if selection.contains(calendar.id) {
                                        Image(systemName: "checkmark").foregroundStyle(Color.brand)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var groupedSources: [String] {
        var seen: [String] = []
        for calendar in calendars where !seen.contains(calendar.source) { seen.append(calendar.source) }
        return seen
    }

    private func toggle(_ id: String) {
        if let index = selection.firstIndex(of: id) {
            selection.remove(at: index)
        } else {
            selection.append(id)
        }
    }
}
