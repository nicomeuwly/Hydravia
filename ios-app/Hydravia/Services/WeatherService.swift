import CoreLocation
import Foundation
import OSLog

/// Outside temperature for the dose's heat bonus.
///
/// Never on the critical path of the unlock ritual: any failure (no
/// permission, no fix, offline, timeout) yields `nil` and the dose simply
/// skips the bonus. It reads the location permission but never asks for it —
/// the prompt belongs to onboarding, not on top of the ritual.
@MainActor
final class WeatherService {
    static let shared = WeatherService()

    private static let cacheLifetime: TimeInterval = 30 * 60
    private static let timeout: Duration = .seconds(5)
    private let logger = Logger(subsystem: "com.nicomeuwly.hydravia", category: "Weather")
    private let locationManager = CLLocationManager()
    private var cached: (celsius: Double, at: Date)?

    var isAuthorized: Bool {
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways: true
        default: false
        }
    }

    /// Current temperature in °C, or `nil` when unknown.
    func currentTemperature() async -> Double? {
        if let cached, Date.now.timeIntervalSince(cached.at) < Self.cacheLifetime {
            return cached.celsius
        }
        guard isAuthorized else { return nil }

        let result = await withTaskGroup(of: Double?.self) { group in
            group.addTask { await self.fetch() }
            group.addTask {
                try? await Task.sleep(for: Self.timeout)
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }

        if let result {
            cached = (result, .now)
        } else {
            logger.info("Temperature unavailable; dose falls back to no heat bonus")
        }
        // A failed refresh may fall back on a recent reading, never a stale one.
        if let cached, Date.now.timeIntervalSince(cached.at) < 3 * 3600 { return result ?? cached.celsius }
        return result
    }

    private func fetch() async -> Double? {
        guard let coordinate = await currentLocation()?.coordinate else { return nil }
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(format: "%.2f", coordinate.latitude)),
            URLQueryItem(name: "longitude", value: String(format: "%.2f", coordinate.longitude)),
            URLQueryItem(name: "current", value: "temperature_2m"),
        ]
        guard let url = components?.url,
              let (data, response) = try? await URLSession.shared.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let decoded = try? JSONDecoder().decode(OpenMeteoResponse.self, from: data)
        else { return nil }
        return decoded.current.temperature2m
    }

    /// A recent fix if the system has one, otherwise the first live update.
    private func currentLocation() async -> CLLocation? {
        if let last = locationManager.location, last.timestamp.timeIntervalSinceNow > -15 * 60 {
            return last
        }
        do {
            for try await update in CLLocationUpdate.liveUpdates(.default) {
                if let location = update.location { return location }
            }
        } catch {
            return nil
        }
        return nil
    }
}

private nonisolated struct OpenMeteoResponse: Decodable, Sendable {
    struct Current: Decodable, Sendable {
        let temperature2m: Double

        enum CodingKeys: String, CodingKey {
            case temperature2m = "temperature_2m"
        }
    }

    let current: Current
}
