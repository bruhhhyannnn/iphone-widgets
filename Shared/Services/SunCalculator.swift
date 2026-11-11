import Foundation

enum SkyPhase: String, Codable, CaseIterable, Identifiable {
    case night, blueHour, goldenHour, day
    var id: String { rawValue }
    var label: String {
        switch self {
        case .night: "Night"
        case .blueHour: "Blue hour"
        case .goldenHour: "Golden hour"
        case .day: "Daylight"
        }
    }
}

struct SunMoment: Equatable, Identifiable {
    enum Kind: String {
        case blueHour, goldenHour, sunrise, sunset, night
        var label: String {
            switch self {
            case .blueHour: "Blue hour"
            case .goldenHour: "Golden hour"
            case .sunrise: "Sunrise"
            case .sunset: "Sunset"
            case .night: "Nightfall"
            }
        }
        var symbol: String {
            switch self {
            case .blueHour: "moon.haze.fill"
            case .goldenHour: "sun.horizon.fill"
            case .sunrise: "sunrise.fill"
            case .sunset: "sunset.fill"
            case .night: "moon.stars.fill"
            }
        }
    }
    var kind: Kind
    var date: Date
    var id: Date { date }
}

/// Sun times for one local day. Any value can be nil near the poles.
struct SunDay: Equatable {
    var dawn: Date?               // −6°, rising: morning blue hour starts
    var morningBlueEnds: Date?    // −4°, rising: morning golden hour starts
    var sunrise: Date?            // −0.833°, rising
    var morningGoldenEnds: Date?  // +6°, rising
    var solarNoon: Date
    var eveningGoldenStarts: Date? // +6°, falling
    var sunset: Date?             // −0.833°, falling
    var eveningBlueStarts: Date?  // −4°, falling
    var dusk: Date?               // −6°, falling: night begins

    var dayLength: TimeInterval? {
        guard let sunrise, let sunset else { return nil }
        return sunset.timeIntervalSince(sunrise)
    }

    var moments: [SunMoment] {
        var list: [SunMoment] = []
        func add(_ kind: SunMoment.Kind, _ date: Date?) {
            if let date { list.append(SunMoment(kind: kind, date: date)) }
        }
        add(.blueHour, dawn)
        add(.goldenHour, morningBlueEnds)
        add(.sunrise, sunrise)
        add(.goldenHour, eveningGoldenStarts)
        add(.sunset, sunset)
        add(.blueHour, eveningBlueStarts)
        add(.night, dusk)
        return list.sorted { $0.date < $1.date }
    }
}

enum SunCalculator {
    // MARK: Solar position (NOAA algorithm)

    /// Sun elevation above the horizon in degrees.
    static func elevation(at date: Date, latitude: Double, longitude: Double) -> Double {
        let ts = date.timeIntervalSince1970
        let jd = ts / 86400 + 2440587.5
        let t = (jd - 2451545) / 36525

        let l0 = (280.46646 + t * (36000.76983 + t * 0.0003032)).truncatingRemainder(dividingBy: 360)
        let m = 357.52911 + t * (35999.05029 - 0.0001537 * t)
        let e = 0.016708634 - t * (0.000042037 + 0.0000001267 * t)
        let c = sin(rad(m)) * (1.914602 - t * (0.004817 + 0.000014 * t))
            + sin(rad(2 * m)) * (0.019993 - 0.000101 * t)
            + sin(rad(3 * m)) * 0.000289
        let omega = 125.04 - 1934.136 * t
        let lambda = l0 + c - 0.00569 - 0.00478 * sin(rad(omega))
        let eps0 = 23 + (26 + (21.448 - t * (46.815 + t * (0.00059 - t * 0.001813))) / 60) / 60
        let eps = eps0 + 0.00256 * cos(rad(omega))
        let declination = asin(sin(rad(eps)) * sin(rad(lambda)))

        let y = pow(tan(rad(eps / 2)), 2)
        let equationOfTime = 4 * deg(
            y * sin(2 * rad(l0))
            - 2 * e * sin(rad(m))
            + 4 * e * y * sin(rad(m)) * cos(2 * rad(l0))
            - 0.5 * y * y * sin(4 * rad(l0))
            - 1.25 * e * e * sin(2 * rad(m))
        )

        let utcMinutes = ts.truncatingRemainder(dividingBy: 86400) / 60
        var trueSolarTime = (utcMinutes + equationOfTime + 4 * longitude).truncatingRemainder(dividingBy: 1440)
        if trueSolarTime < 0 { trueSolarTime += 1440 }
        let hourAngle = trueSolarTime / 4 - 180

        let cosZenith = sin(rad(latitude)) * sin(declination)
            + cos(rad(latitude)) * cos(declination) * cos(rad(hourAngle))
        return 90 - deg(acos(min(1, max(-1, cosZenith))))
    }

    static func phase(at date: Date, latitude: Double, longitude: Double) -> SkyPhase {
        let elevation = elevation(at: date, latitude: latitude, longitude: longitude)
        switch elevation {
        case ..<(-6): return .night
        case ..<(-4): return .blueHour
        case ..<6: return .goldenHour
        default: return .day
        }
    }

    // MARK: Day events

    static func day(containing date: Date, location: SavedLocation) -> SunDay {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = location.timeZone
        let start = calendar.startOfDay(for: date)
        let lat = location.latitude, lon = location.longitude

        let step: TimeInterval = 600
        let samples: [(Date, Double)] = (0...144).map { i in
            let d = start.addingTimeInterval(Double(i) * step)
            return (d, elevation(at: d, latitude: lat, longitude: lon))
        }

        func crossing(_ threshold: Double, rising: Bool) -> Date? {
            for i in 1..<samples.count {
                let (d0, e0) = samples[i - 1]
                let (_, e1) = samples[i]
                let f0 = e0 - threshold, f1 = e1 - threshold
                let isRising = f0 < 0 && f1 >= 0
                let isFalling = f0 >= 0 && f1 < 0
                guard rising ? isRising : isFalling else { continue }
                var a = d0.timeIntervalSince1970, b = a + step
                var fa = f0
                for _ in 0..<14 {
                    let mid = (a + b) / 2
                    let fm = elevation(at: Date(timeIntervalSince1970: mid), latitude: lat, longitude: lon) - threshold
                    if (fa < 0) == (fm < 0) { a = mid; fa = fm } else { b = mid }
                }
                return Date(timeIntervalSince1970: (a + b) / 2)
            }
            return nil
        }

        var noon = samples.max { $0.1 < $1.1 }?.0 ?? start.addingTimeInterval(43200)
        var best = -Double.infinity
        for minute in stride(from: -10.0, through: 10.0, by: 1.0) {
            let d = noon.addingTimeInterval(minute * 60)
            let e = elevation(at: d, latitude: lat, longitude: lon)
            if e > best { best = e; noon = d }
        }

        return SunDay(
            dawn: crossing(-6, rising: true),
            morningBlueEnds: crossing(-4, rising: true),
            sunrise: crossing(-0.833, rising: true),
            morningGoldenEnds: crossing(6, rising: true),
            solarNoon: noon,
            eveningGoldenStarts: crossing(6, rising: false),
            sunset: crossing(-0.833, rising: false),
            eveningBlueStarts: crossing(-4, rising: false),
            dusk: crossing(-6, rising: false)
        )
    }

    /// The next sun moment after `date`, looking at today and tomorrow.
    static func nextMoment(after date: Date, location: SavedLocation) -> SunMoment? {
        let today = day(containing: date, location: location)
        if let next = today.moments.first(where: { $0.date > date }) { return next }
        let tomorrow = day(containing: date.addingTimeInterval(86400), location: location)
        return tomorrow.moments.first(where: { $0.date > date })
    }

    // MARK: Moon

    /// 0 = new moon, 0.5 = full moon, back to 1.
    static func moonPhase(at date: Date) -> Double {
        let jd = date.timeIntervalSince1970 / 86400 + 2440587.5
        let synodicMonth = 29.530588853
        var age = (jd - 2451550.26).truncatingRemainder(dividingBy: synodicMonth)
        if age < 0 { age += synodicMonth }
        return age / synodicMonth
    }

    static func moonSymbol(at date: Date) -> String {
        let p = moonPhase(at: date)
        switch p {
        case ..<0.03, 0.97...: return "moonphase.new.moon"
        case ..<0.22: return "moonphase.waxing.crescent"
        case ..<0.28: return "moonphase.first.quarter"
        case ..<0.47: return "moonphase.waxing.gibbous"
        case ..<0.53: return "moonphase.full.moon"
        case ..<0.72: return "moonphase.waning.gibbous"
        case ..<0.78: return "moonphase.last.quarter"
        default: return "moonphase.waning.crescent"
        }
    }

    private static func rad(_ d: Double) -> Double { d * .pi / 180 }
    private static func deg(_ r: Double) -> Double { r * 180 / .pi }
}
