import SwiftUI
import WidgetKit

struct GazetteData {
    var date: Date
    var events: [AgendaEvent]
    var reminders: [ReminderItem]
    var weather: WeatherSnapshot?
    var news: NewsSnapshot?
    var sunDay: SunDay?
    var timeZone: TimeZone
    var unit: TemperatureUnit
    var hasCalendarAccess: Bool
}

struct GazetteBackground: View {
    var look: WidgetLook
    var body: some View {
        switch look {
        case .glass:
            Color.clear
        case .light, .dark:
            ZStack {
                look == .light ? Color(hex: 0xF2ECDF) : Color(hex: 0x1E1D1A)
                PaperGrain(dark: look == .dark)
            }
        }
    }
}

struct PaperGrain: View {
    var dark: Bool
    var body: some View {
        Canvas { context, size in
            var random = SeededRandom(seed: 42)
            for _ in 0..<700 {
                let x = random.next() * size.width
                let y = random.next() * size.height
                let r = 0.3 + random.next() * 0.6
                let alpha = 0.04 + random.next() * 0.07
                context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                             with: .color((dark ? Color.white : Color.black).opacity(alpha)))
            }
        }
    }
}

struct GazetteContent: View {
    var data: GazetteData
    var settings: GazetteSettings
    var look: WidgetLook

    private var ink: Color {
        switch look {
        case .light: Color(hex: 0x1B1A17)
        case .dark: Color(hex: 0xEDE6D6)
        case .glass: .white
        }
    }
    private var faded: Color { ink.opacity(0.62) }
    private var type: GazetteTypeface { settings.typeface }

    private var upcoming: [AgendaEvent] { data.events.filter { $0.end > data.date } }
    private var lead: AgendaEvent? { upcoming.first { !$0.isAllDay } ?? upcoming.first }
    private var others: [AgendaEvent] { upcoming.filter { $0.id != lead?.id } }
    private var showNews: Bool { settings.news != .none }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            masthead
            rule(2)
            leadStory
            rule(1)
            alsoAndReminders
            if showNews { newsSection }
            Spacer(minLength: 0)
            footer
        }
        .foregroundStyle(ink)
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // MARK: Sections

    private var masthead: some View {
        HStack(alignment: .lastTextBaseline) {
            Text(Fmt.template(data.date, "MMMd") + ".")
                .font(type.font(13, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(Fmt.string(data.date, "EEEE"))
                .font(type.font(30, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .layoutPriority(1)
                .widgetAccentable()
            Group {
                if let weather = data.weather {
                    Text("\(WeatherService.temperature(weather.currentC, unit: data.unit)), \(WeatherService.description(for: weather.code))")
                } else {
                    Text(" ")
                }
            }
            .font(type.font(13, weight: .semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    @ViewBuilder
    private var leadStory: some View {
        if !data.hasCalendarAccess {
            VStack(alignment: .leading, spacing: 2) {
                Text("STOP THE PRESSES")
                    .font(type.font(22, weight: .bold))
                Text("Allow calendar access in Glassboard to print your day.")
                    .font(type.font(12, italic: true))
                    .foregroundStyle(faded)
            }
        } else if let lead {
            VStack(alignment: .leading, spacing: 2) {
                Text(lead.title.uppercased())
                    .font(type.font(23, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                Text(leadLine(lead))
                    .font(type.font(12, italic: true))
                    .foregroundStyle(faded)
                    .lineLimit(1)
            }
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Text("A QUIET DAY AHEAD")
                    .font(type.font(23, weight: .bold))
                Text("Nothing on the calendar. Enjoy it.")
                    .font(type.font(12, italic: true))
                    .foregroundStyle(faded)
            }
        }
    }

    private func leadLine(_ event: AgendaEvent) -> String {
        let day = Fmt.dayLabel(event.start, now: data.date)
        var line = event.isAllDay ? "\(day), all day" : "\(day) at \(Fmt.time(event.start))"
        if event.start <= data.date && !event.isAllDay { line = "Happening now, until \(Fmt.time(event.end))" }
        if let location = event.location { line += ". \(location)" }
        return line + "."
    }

    private var alsoAndReminders: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                label("Also")
                if others.isEmpty {
                    Text("Nothing else scheduled.")
                        .font(type.font(12, italic: true))
                        .foregroundStyle(faded)
                } else {
                    ForEach(others.prefix(showNews ? 2 : 4)) { event in
                        VStack(alignment: .leading, spacing: 0) {
                            Text(event.title)
                                .font(type.font(13, weight: .semibold))
                                .lineLimit(1)
                            Text(eventWhen(event))
                                .font(type.font(10))
                                .foregroundStyle(faded)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if settings.showReminders {
                VStack(alignment: .leading, spacing: 4) {
                    label("Reminders")
                    if data.reminders.isEmpty {
                        Text("All done.")
                            .font(type.font(12, italic: true))
                            .foregroundStyle(faded)
                    } else {
                        ForEach(data.reminders.prefix(showNews ? 2 : 4)) { item in
                            VStack(alignment: .leading, spacing: 0) {
                                Text(item.title)
                                    .font(type.font(13, weight: .semibold))
                                    .lineLimit(1)
                                Text(reminderDue(item))
                                    .font(type.font(10))
                                    .foregroundStyle(faded)
                            }
                        }
                    }
                }
                .padding(7)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(Rectangle().strokeBorder(ink.opacity(0.5), lineWidth: 0.8))
            }
        }
    }

    private func eventWhen(_ event: AgendaEvent) -> String {
        let day = Fmt.dayLabel(event.start, now: data.date)
        return event.isAllDay ? "\(day), all day." : "\(day), \(Fmt.time(event.start))."
    }

    private func reminderDue(_ item: ReminderItem) -> String {
        guard let due = item.due else { return "No date." }
        let cal = Calendar.current
        if due < cal.startOfDay(for: data.date) { return "Overdue." }
        let day = Fmt.dayLabel(due, now: data.date)
        return item.dueHasTime ? "Due \(day.lowercased()), \(Fmt.time(due))." : "Due \(day.lowercased())."
    }

    private var newsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 0) {
                label("In the news · \(settings.news.shortLabel)")
                if let fetched = data.news?.fetchedAt {
                    label(" · \(Fmt.time(fetched))")
                }
            }
            if let headlines = data.news?.headlines, !headlines.isEmpty {
                let items = Array(headlines.prefix(4))
                Grid(alignment: .topLeading, horizontalSpacing: 12, verticalSpacing: 6) {
                    ForEach(0..<((items.count + 1) / 2), id: \.self) { row in
                        GridRow {
                            headline(items[row * 2])
                            if row * 2 + 1 < items.count {
                                headline(items[row * 2 + 1])
                            } else {
                                Color.clear.frame(height: 1)
                            }
                        }
                    }
                }
            } else {
                Text("The wire is quiet. Headlines arrive when the widget refreshes.")
                    .font(type.font(12, italic: true))
                    .foregroundStyle(faded)
            }
        }
    }

    @ViewBuilder
    private func headline(_ item: Headline) -> some View {
        let body = VStack(alignment: .leading, spacing: 1) {
            Text(item.title)
                .font(type.font(12, weight: .semibold))
                .lineLimit(3)
                .multilineTextAlignment(.leading)
            if let age = Fmt.age(item.published, now: data.date) {
                Text(age)
                    .font(type.font(9))
                    .foregroundStyle(faded)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        if let link = item.link, let url = URL(string: link) {
            Link(destination: url) { body }
        } else {
            body
        }
    }

    private var footer: some View {
        VStack(spacing: 4) {
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 1) {
                    label("Tomorrow")
                    if let tomorrow = data.weather?.tomorrow {
                        HStack(spacing: 4) {
                            Image(systemName: WeatherService.symbol(for: tomorrow.code))
                                .font(.system(size: 10))
                            Text("\(WeatherService.temperature(tomorrow.maxC, unit: data.unit)) high, \(WeatherService.temperature(tomorrow.minC, unit: data.unit)) low.")
                        }
                        .font(type.font(11))
                    } else {
                        Text("Forecast unavailable.").font(type.font(11))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .leading, spacing: 1) {
                    label("Sun")
                    if let rise = data.sunDay?.sunrise, let set = data.sunDay?.sunset {
                        Text("Rises \(Fmt.time(rise, timeZone: data.timeZone)), sets \(Fmt.time(set, timeZone: data.timeZone)).")
                            .font(type.font(11))
                    } else {
                        Text("Set a location for sun times.").font(type.font(11))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(ink.opacity(0.5), lineWidth: 0.8))

            label(Fmt.edition(for: data.date))
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: Helpers

    private func label(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 8.5, weight: .semibold))
            .tracking(1.6)
            .foregroundStyle(faded)
            .lineLimit(1)
    }

    private func rule(_ height: CGFloat) -> some View {
        Rectangle().fill(ink).frame(height: height)
    }
}
