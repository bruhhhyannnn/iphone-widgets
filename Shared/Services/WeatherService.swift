import Foundation

struct WeatherSnapshot: Codable, Equatable {
    struct Day: Codable, Equatable, Identifiable {
        var date: Date
        var code: Int
        var maxC: Double
        var minC: Double
        var id: Date { date }
    }
    struct Hour: Codable, Equatable, Identifiable {
        var date: Date
        var code: Int
        var tempC: Double
        var id: Date { date }
    }

    var fetchedAt: Date
    var latitude: Double
    var longitude: Double
    var currentC: Double
    var code: Int
    var isDay: Bool
    var days: [Day]
    var hours: [Hour]

    var today: Day? { days.first }
    var tomorrow: Day? { days.count > 1 ? days[1] : nil }

    func isFresh(for location: SavedLocation, maxAge: TimeInterval = 30 * 60) -> Bool {
        abs(latitude - location.latitude) < 0.05
            && abs(longitude - location.longitude) < 0.05
            && Date().timeIntervalSince(fetchedAt) < maxAge
    }

    static let sample = WeatherSnapshot(
        fetchedAt: .now, latitude: 0, longitude: 0, currentC: 24, code: 0, isDay: true,
        days: (0..<6).map { i in
            Day(date: Calendar.current.startOfDay(for: .now).addingTimeInterval(Double(i) * 86400),
                code: [0, 2, 3, 61, 1, 0][i], maxC: [24, 25, 22, 19, 21, 23][i], minC: [15, 16, 14, 12, 13, 14][i])
        },
        hours: (0..<6).map { i in
            Hour(date: Date.now.addingTimeInterval(Double(i) * 3600), code: [0, 0, 1, 2, 2, 3][i], tempC: [24, 24, 23, 22, 20, 19][i])
        }
    )
}

enum WeatherService {
    /// Returns cached weather when it is still fresh, otherwise downloads new data.
    static func current(for location: SavedLocation, maxAge: TimeInterval = 30 * 60) async -> WeatherSnapshot? {
        let cached: WeatherSnapshot? = SharedStore.load(SharedStore.Key.weather, default: nil)
        if let cached, cached.isFresh(for: location, maxAge: maxAge) { return cached }
        if let fresh = try? await fetch(for: location) {
            SharedStore.save(fresh, SharedStore.Key.weather)
            return fresh
        }
        return cached
    }

    static var cached: WeatherSnapshot? {
        SharedStore.load(SharedStore.Key.weather, default: nil)
    }

    static func fetch(for location: SavedLocation) async throws -> WeatherSnapshot {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(format: "%.4f", location.latitude)),
            URLQueryItem(name: "longitude", value: String(format: "%.4f", location.longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,weather_code,is_day"),
            URLQueryItem(name: "hourly", value: "temperature_2m,weather_code"),
            URLQueryItem(name: "daily", value: "weather_code,temperature_2m_max,temperature_2m_min"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "forecast_days", value: "7"),
            URLQueryItem(name: "forecast_hours", value: "12"),
            URLQueryItem(name: "timeformat", value: "unixtime"),
        ]
        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 15
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)

        let daily = response.daily
        var days: [WeatherSnapshot.Day] = []
        for i in daily.time.indices {
            guard let code = daily.weather_code[safe: i] ?? nil,
                  let maxC = daily.temperature_2m_max[safe: i] ?? nil,
                  let minC = daily.temperature_2m_min[safe: i] ?? nil else { continue }
            days.append(.init(date: Date(timeIntervalSince1970: daily.time[i]), code: code, maxC: maxC, minC: minC))
        }
        let hourly = response.hourly
        var hours: [WeatherSnapshot.Hour] = []
        for i in hourly.time.indices {
            guard let code = hourly.weather_code[safe: i] ?? nil,
                  let temp = hourly.temperature_2m[safe: i] ?? nil else { continue }
            hours.append(.init(date: Date(timeIntervalSince1970: hourly.time[i]), code: code, tempC: temp))
        }
        return WeatherSnapshot(
            fetchedAt: .now,
            latitude: location.latitude,
            longitude: location.longitude,
            currentC: response.current.temperature_2m,
            code: response.current.weather_code,
            isDay: response.current.is_day == 1,
            days: days,
            hours: hours
        )
    }

    // MARK: Formatting

    static func temperature(_ celsius: Double, unit: TemperatureUnit) -> String {
        let value = unit.usesFahrenheit ? celsius * 9 / 5 + 32 : celsius
        return "\(Int(value.rounded()))°"
    }

    static func symbol(for code: Int, isDay: Bool = true) -> String {
        switch code {
        case 0: return isDay ? "sun.max.fill" : "moon.stars.fill"
        case 1, 2: return isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51, 53, 55, 56, 57: return "cloud.drizzle.fill"
        case 61, 63, 66, 80, 81: return "cloud.rain.fill"
        case 65, 67, 82: return "cloud.heavyrain.fill"
        case 71, 73, 75, 77, 85, 86: return "cloud.snow.fill"
        case 95, 96, 99: return "cloud.bolt.rain.fill"
        default: return "cloud.fill"
        }
    }

    static func description(for code: Int) -> String {
        switch code {
        case 0: return "clear"
        case 1: return "mostly clear"
        case 2: return "partly cloudy"
        case 3: return "overcast"
        case 45, 48: return "foggy"
        case 51, 53, 55, 56, 57: return "drizzle"
        case 61, 63, 66, 80, 81: return "rain"
        case 65, 67, 82: return "heavy rain"
        case 71, 73, 75, 77, 85, 86: return "snow"
        case 95, 96, 99: return "storms"
        default: return "cloudy"
        }
    }
}

private struct OpenMeteoResponse: Decodable {
    struct Current: Decodable {
        var temperature_2m: Double
        var weather_code: Int
        var is_day: Int
    }
    struct Hourly: Decodable {
        var time: [Double]
        var temperature_2m: [Double?]
        var weather_code: [Int?]
    }
    struct Daily: Decodable {
        var time: [Double]
        var weather_code: [Int?]
        var temperature_2m_max: [Double?]
        var temperature_2m_min: [Double?]
    }
    var current: Current
    var hourly: Hourly
    var daily: Daily
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
