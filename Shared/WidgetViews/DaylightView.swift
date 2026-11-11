import SwiftUI
import WidgetKit

struct DaylightData {
    var date: Date
    var location: SavedLocation?
    var sunDay: SunDay?
    var next: SunMoment?
    var phase: SkyPhase
    var isMorning: Bool
    /// 0…1 along the day arc while the sun is up, otherwise along the night arc.
    var progress: Double
    var sunIsUp: Bool

    static func make(at date: Date, location: SavedLocation?) -> DaylightData {
        guard let location else {
            return DaylightData(date: date, location: nil, sunDay: nil, next: nil, phase: .day,
                                isMorning: true, progress: 0.5, sunIsUp: true)
        }
        let today = SunCalculator.day(containing: date, location: location)
        let phase = SunCalculator.phase(at: date, latitude: location.latitude, longitude: location.longitude)
        let isMorning = date < today.solarNoon

        var progress = 0.5
        var sunIsUp = false
        if let rise = today.sunrise, let set = today.sunset, date >= rise, date <= set {
            sunIsUp = true
            progress = date.timeIntervalSince(rise) / set.timeIntervalSince(rise)
        } else {
            // Night arc: from the previous sunset to the next sunrise.
            let yesterday = SunCalculator.day(containing: date.addingTimeInterval(-86400), location: location)
            let tomorrow = SunCalculator.day(containing: date.addingTimeInterval(86400), location: location)
            var start = yesterday.sunset
            if let todaySunset = today.sunset, date > todaySunset { start = todaySunset }
            var end = tomorrow.sunrise
            if let todaySunrise = today.sunrise, date < todaySunrise { end = todaySunrise }
            if let start, let end, end > start {
                progress = date.timeIntervalSince(start) / end.timeIntervalSince(start)
            }
        }
        return DaylightData(date: date, location: location, sunDay: today,
                            next: SunCalculator.nextMoment(after: date, location: location),
                            phase: phase, isMorning: isMorning,
                            progress: min(1, max(0, progress)), sunIsUp: sunIsUp)
    }

    enum PreviewScene: String, CaseIterable, Identifiable {
        case now, dawn, noon, dusk, night
        var id: String { rawValue }
        var label: String { rawValue.capitalized }
    }

    /// Lets the app preview the widget at different times of today.
    static func preview(_ scene: PreviewScene, location: SavedLocation?) -> DaylightData {
        let loc = location ?? .sample
        let day = SunCalculator.day(containing: .now, location: loc)
        let date: Date
        switch scene {
        case .now: date = .now
        case .dawn: date = (day.morningBlueEnds ?? day.solarNoon.addingTimeInterval(-6 * 3600)).addingTimeInterval(8 * 60)
        case .noon: date = day.solarNoon
        case .dusk: date = (day.eveningGoldenStarts ?? day.solarNoon.addingTimeInterval(5 * 3600)).addingTimeInterval(20 * 60)
        case .night: date = (day.dusk ?? day.solarNoon.addingTimeInterval(8 * 3600)).addingTimeInterval(90 * 60)
        }
        return make(at: date, location: loc)
    }
}

// MARK: - Background

struct DaylightBackground: View {
    var data: DaylightData
    var look: WidgetLook
    var showStars: Bool

    var body: some View {
        if look == .glass {
            Color.clear
        } else {
            ZStack {
                LinearGradient(colors: skyColors, startPoint: .top, endPoint: .bottom)
                if showStars && starOpacity > 0 {
                    StarField(seed: 7).opacity(starOpacity)
                }
                // Soft horizon glow
                RadialGradient(colors: [glow.opacity(0.55), .clear], center: .bottom, startRadius: 0, endRadius: 220)
            }
        }
    }

    private var starOpacity: Double {
        switch data.phase {
        case .night: 1
        case .blueHour: 0.45
        default: 0
        }
    }

    private var skyColors: [Color] {
        switch data.phase {
        case .night: [Color(hex: 0x070B1F), Color(hex: 0x111A3D), Color(hex: 0x1D2752)]
        case .blueHour: [Color(hex: 0x16214F), Color(hex: 0x2F4A8F), Color(hex: 0x6D7FBE)]
        case .goldenHour where data.isMorning: [Color(hex: 0x3B5597), Color(hex: 0xC98A8A), Color(hex: 0xF5C489)]
        case .goldenHour: [Color(hex: 0x2B3A74), Color(hex: 0xC8676C), Color(hex: 0xF2A257)]
        case .day: [Color(hex: 0x2A72CF), Color(hex: 0x5FA6E6), Color(hex: 0xB9DDF6)]
        }
    }

    private var glow: Color {
        switch data.phase {
        case .night: Color(hex: 0x3A4C8C)
        case .blueHour: Color(hex: 0x8FA0E0)
        case .goldenHour: Color(hex: 0xFFC27A)
        case .day: Color(hex: 0xFFFFFF)
        }
    }
}

struct StarField: View {
    var seed: UInt64
    var count = 40

    var body: some View {
        Canvas { context, size in
            var random = SeededRandom(seed: seed)
            for _ in 0..<count {
                let x = random.next() * size.width
                let y = random.next() * size.height * 0.7
                let r = 0.5 + random.next() * 1.1
                let alpha = 0.35 + random.next() * 0.65
                context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r * 2, height: r * 2)),
                             with: .color(.white.opacity(alpha)))
            }
        }
    }
}

// MARK: - Content

struct DaylightContent: View {
    var data: DaylightData
    var settings: DaylightSettings
    var family: WidgetFamily
    var look: WidgetLook

    private var timeZone: TimeZone { data.location?.timeZone ?? .current }

    var body: some View {
        Group {
            if data.location == nil {
                setupPrompt
            } else if family == .systemSmall {
                small
            } else {
                medium
            }
        }
        .foregroundStyle(.white)
    }

    private var setupPrompt: some View {
        VStack(spacing: 8) {
            Image(systemName: "location.circle.fill").font(.system(size: 30))
            Text("Set your location in Glassboard")
                .font(.system(size: 13, weight: .semibold))
                .multilineTextAlignment(.center)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var nextLabel: String {
        guard let next = data.next else { return "Today" }
        return "Next · \(next.kind.label)"
    }

    private var bigTime: some View {
        let parts = Fmt.timeParts(data.next?.date ?? data.date, timeZone: timeZone)
        return HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(parts.main)
                .font(.system(size: family == .systemSmall ? 38 : 46, weight: .bold))
                .fontWidth(.expanded)
                .minimumScaleFactor(0.6)
            if let period = parts.period {
                Text(period)
                    .font(.system(size: family == .systemSmall ? 14 : 17, weight: .bold))
                    .fontWidth(.expanded)
                    .opacity(0.85)
            }
        }
        .lineLimit(1)
        .widgetAccentable()
    }

    @ViewBuilder
    private var countdown: some View {
        if settings.showCountdown, let next = data.next {
            Text("in \(Fmt.duration(next.date.timeIntervalSince(data.date)))")
                .font(.system(size: 12, weight: .semibold))
                .opacity(0.8)
        }
    }

    private var medium: some View {
        ZStack {
            SkyArc(data: data, look: look)
                .padding(.horizontal, 20)
                .padding(.top, 54)
                .padding(.bottom, 34)

            VStack(spacing: 2) {
                Text(nextLabel.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.6)
                    .opacity(0.85)
                bigTime
                countdown
                Spacer(minLength: 0)
                bottomRow
            }
            .padding(.top, 14)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                Image(systemName: data.next?.kind.symbol ?? "sun.max.fill")
                Text((data.next?.kind.label ?? "Today").uppercased())
                    .tracking(1.2)
            }
            .font(.system(size: 10, weight: .bold))
            .opacity(0.85)
            bigTime
            countdown
            Spacer(minLength: 0)
            SkyArc(data: data, look: look)
                .frame(height: 30)
                .padding(.horizontal, 4)
            HStack {
                Label(time(data.sunDay?.sunrise), systemImage: "sunrise.fill")
                Spacer(minLength: 4)
                Label(time(data.sunDay?.sunset), systemImage: "sunset.fill")
            }
            .labelStyle(CompactLabelStyle())
            .font(.system(size: 11, weight: .semibold))
        }
        .padding(14)
    }

    private var bottomRow: some View {
        HStack(alignment: .lastTextBaseline) {
            Label(time(data.sunDay?.sunrise), systemImage: "sunrise.fill")
            Spacer(minLength: 6)
            HStack(spacing: 6) {
                Text((data.location?.name ?? "").uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1)
                    .lineLimit(1)
                if let length = data.sunDay?.dayLength {
                    Text(Fmt.duration(length)).opacity(0.75)
                }
            }
            Spacer(minLength: 6)
            Label(time(data.sunDay?.sunset), systemImage: "sunset.fill")
                .labelStyle(TrailingIconLabelStyle())
        }
        .labelStyle(CompactLabelStyle())
        .font(.system(size: 12, weight: .semibold))
    }

    private func time(_ date: Date?) -> String {
        date.map { Fmt.time($0, timeZone: timeZone) } ?? "—"
    }
}

/// The dashed arc with the sun (or moon) placed at the current position.
struct SkyArc: View {
    var data: DaylightData
    var look: WidgetLook

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let t = data.progress
            let point = CGPoint(x: w * t, y: h - sin(t * .pi) * h)
            ZStack {
                ArcShape()
                    .stroke(style: StrokeStyle(lineWidth: 1.2, dash: [3, 4]))
                    .opacity(0.45)
                Rectangle()
                    .frame(height: 1)
                    .opacity(0.3)
                    .position(x: w / 2, y: h)
                if data.sunIsUp {
                    Circle()
                        .fill(look == .glass ? Color.white : Color(hex: 0xFFE7A3))
                        .frame(width: 14, height: 14)
                        .shadow(color: Color(hex: 0xFFD27A).opacity(0.9), radius: 8)
                        .position(point)
                        .widgetAccentable()
                } else {
                    Image(systemName: SunCalculator.moonSymbol(at: data.date))
                        .font(.system(size: 15, weight: .semibold))
                        .shadow(color: .white.opacity(0.5), radius: 6)
                        .position(point)
                        .widgetAccentable()
                }
            }
        }
    }
}

struct ArcShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let steps = 48
        for i in 0...steps {
            let t = Double(i) / Double(steps)
            let p = CGPoint(x: rect.minX + rect.width * t, y: rect.maxY - sin(t * .pi) * rect.height)
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        return path
    }
}

struct CompactLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.icon.font(.system(size: 10, weight: .bold)).opacity(0.85)
            configuration.title
        }
    }
}

struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.title
            configuration.icon.font(.system(size: 10, weight: .bold)).opacity(0.85)
        }
    }
}
