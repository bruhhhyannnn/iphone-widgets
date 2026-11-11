import SwiftUI
import WidgetKit

struct AgendaData {
    var date: Date
    var events: [AgendaEvent]
    var weather: WeatherSnapshot?
    var hasCalendarAccess: Bool
    var unit: TemperatureUnit
    var locationName: String?

    /// The event that is happening now or starts next (timed events before all-day ones).
    var nextEvent: AgendaEvent? {
        let upcoming = events.filter { $0.end > date }
        return upcoming.first { !$0.isAllDay } ?? upcoming.first
    }
}

struct AgendaBackground: View {
    var look: WidgetLook
    var body: some View {
        switch look {
        case .light: LinearGradient(colors: [Color(hex: 0xFAF9F6), Color(hex: 0xEFEDE8)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .dark: LinearGradient(colors: [Color(hex: 0x23252A), Color(hex: 0x17181B)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .glass: Color.clear
        }
    }
}

struct AgendaContent: View {
    var data: AgendaData
    var settings: AgendaSettings
    var family: WidgetFamily
    var look: WidgetLook
    /// In the app the side buttons call this; in the widget they run SetAgendaModeIntent.
    var onSelectMode: ((AgendaMode) -> Void)?

    private var palette: Palette { Palette(look, accent: settings.accent) }

    var body: some View {
        if family == .systemSmall {
            nextView(compact: true)
                .padding(14)
        } else {
            HStack(spacing: 12) {
                Group {
                    switch settings.mode {
                    case .next: nextView(compact: false)
                    case .week: weekView
                    case .sky: skyView
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                modeRail
            }
            .padding(14)
        }
    }

    // MARK: Now

    @ViewBuilder
    private func nextView(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 2 : 3) {
            HStack(alignment: .firstTextBaseline) {
                Text(headline.uppercased())
                    .font(.system(size: compact ? 10 : 11, weight: .heavy))
                    .tracking(1.8)
                    .foregroundStyle(palette.accent)
                    .widgetAccentable()
                    .lineLimit(1)
                Spacer(minLength: 4)
                if let weather = data.weather, !compact {
                    weatherBadge(weather)
                }
            }
            Spacer(minLength: 0)
            if !data.hasCalendarAccess {
                Text("Allow calendar access in Glassboard")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(palette.primary)
                Spacer(minLength: 0)
            } else if let event = data.nextEvent {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(event.title)
                        .font(.system(size: compact ? 15 : 19, weight: .bold))
                        .foregroundStyle(palette.primary)
                    if !compact, let location = event.location {
                        Text(location)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(palette.secondary)
                    }
                }
                .lineLimit(1)
                bigTime(for: event, compact: compact)
                Spacer(minLength: 0)
                Text(Fmt.template(event.start, compact ? "EEEMMMd" : "EEEEMMMMd"))
                    .font(.system(size: compact ? 11 : 13, weight: .medium))
                    .foregroundStyle(palette.secondary)
            } else {
                Text("Nothing planned")
                    .font(.system(size: compact ? 15 : 19, weight: .bold))
                    .foregroundStyle(palette.primary)
                Text(Fmt.string(data.date, "d"))
                    .font(.system(size: compact ? 36 : 44, weight: .bold))
                    .fontWidth(.expanded)
                    .foregroundStyle(palette.accent)
                    .widgetAccentable()
                Spacer(minLength: 0)
                Text(Fmt.template(data.date, "EEEEMMMMd"))
                    .font(.system(size: compact ? 11 : 13, weight: .medium))
                    .foregroundStyle(palette.secondary)
            }
        }
    }

    private var headline: String {
        guard let event = data.nextEvent else { return "Today" }
        if event.start <= data.date { return "Now" }
        if event.isAllDay { return Fmt.dayLabel(event.start, now: data.date) }
        let minutes = event.start.timeIntervalSince(data.date) / 60
        if minutes < 60 { return "In \(Int(minutes.rounded())) min" }
        return Fmt.dayLabel(event.start, now: data.date)
    }

    @ViewBuilder
    private func bigTime(for event: AgendaEvent, compact: Bool) -> some View {
        if event.isAllDay {
            Text("All day")
                .font(.system(size: compact ? 26 : 36, weight: .bold))
                .fontWidth(.expanded)
                .foregroundStyle(palette.accent)
                .widgetAccentable()
        } else {
            let parts = Fmt.timeParts(event.start)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(parts.main)
                    .font(.system(size: compact ? 30 : 42, weight: .bold))
                    .fontWidth(.expanded)
                if let period = parts.period {
                    Text(period)
                        .font(.system(size: compact ? 13 : 17, weight: .bold))
                        .fontWidth(.expanded)
                }
            }
            .foregroundStyle(palette.accent)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .widgetAccentable()
        }
    }

    private func weatherBadge(_ weather: WeatherSnapshot) -> some View {
        HStack(spacing: 4) {
            Image(systemName: WeatherService.symbol(for: weather.code, isDay: weather.isDay))
                .symbolRenderingMode(.hierarchical)
            Text(WeatherService.temperature(weather.currentC, unit: data.unit))
        }
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(palette.primary)
    }

    // MARK: Week

    private var weekView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("THE WEEK")
                .font(.system(size: 11, weight: .heavy))
                .tracking(1.8)
                .foregroundStyle(palette.accent)
                .widgetAccentable()
            if !data.hasCalendarAccess {
                Text("Allow calendar access in Glassboard")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(palette.secondary)
            } else if data.events.isEmpty {
                Text("A clear week.")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(palette.secondary)
            } else {
                ForEach(data.events.filter { $0.end > data.date }.prefix(4)) { event in
                    HStack(spacing: 8) {
                        Capsule()
                            .fill(event.colorHex.map { Color(hex: $0) } ?? palette.accent)
                            .frame(width: 3, height: 22)
                            .widgetAccentable()
                        VStack(alignment: .leading, spacing: 0) {
                            Text(event.title)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(palette.primary)
                            Text(eventWhen(event))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(palette.secondary)
                        }
                        .lineLimit(1)
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func eventWhen(_ event: AgendaEvent) -> String {
        let day = Fmt.dayLabel(event.start, now: data.date)
        return event.isAllDay ? "\(day) · All day" : "\(day) · \(Fmt.time(event.start))"
    }

    // MARK: Sky

    @ViewBuilder
    private var skyView: some View {
        if let weather = data.weather {
            VStack(alignment: .leading, spacing: 4) {
                Text(("Sky · " + (data.locationName ?? "Here")).uppercased())
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(1.8)
                    .foregroundStyle(palette.accent)
                    .lineLimit(1)
                    .widgetAccentable()
                HStack(alignment: .center, spacing: 8) {
                    Text(WeatherService.temperature(weather.currentC, unit: data.unit))
                        .font(.system(size: 40, weight: .bold))
                        .fontWidth(.expanded)
                        .foregroundStyle(palette.primary)
                    VStack(alignment: .leading, spacing: 0) {
                        Image(systemName: WeatherService.symbol(for: weather.code, isDay: weather.isDay))
                            .symbolRenderingMode(.multicolor)
                            .font(.system(size: 18))
                        Text(WeatherService.description(for: weather.code).capitalized)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(palette.secondary)
                    }
                }
                Spacer(minLength: 0)
                HStack(spacing: 0) {
                    ForEach(weather.days.prefix(5)) { day in
                        VStack(spacing: 2) {
                            Text(Fmt.string(day.date, "EEE").uppercased())
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(palette.secondary)
                            Image(systemName: WeatherService.symbol(for: day.code))
                                .symbolRenderingMode(.multicolor)
                                .font(.system(size: 13))
                                .frame(height: 16)
                            Text(WeatherService.temperature(day.maxC, unit: data.unit))
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(palette.primary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("SKY")
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(1.8)
                    .foregroundStyle(palette.accent)
                Text(data.locationName == nil ? "Set your location in Glassboard" : "Weather is loading…")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(palette.secondary)
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: Mode buttons

    private var modeRail: some View {
        VStack(spacing: 6) {
            ForEach(AgendaMode.allCases) { mode in
                modeButton(mode)
            }
        }
        .padding(5)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(palette.fill))
    }

    @ViewBuilder
    private func modeButton(_ mode: AgendaMode) -> some View {
        let selected = settings.mode == mode
        let label = Image(systemName: mode.symbol)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(selected ? palette.onAccent : palette.secondary)
            .frame(width: 36, height: 36)
            .background {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(selected ? palette.accent : Color.clear)
                    .widgetAccentable()
            }
        if let onSelectMode {
            Button { onSelectMode(mode) } label: { label }.buttonStyle(.plain)
        } else {
            Button(intent: SetAgendaModeIntent(mode: mode)) { label }.buttonStyle(.plain)
        }
    }
}
