import CoreLocation
import Observation
import UIKit

/// The location permission, observable. Asking only ever happens from an
/// explicit tap (onboarding step, settings row) — never on top of the ritual.
@MainActor
@Observable
final class LocationPermission: NSObject, CLLocationManagerDelegate {
    enum Status { case notDetermined, granted, denied }

    private(set) var status: Status = .notDetermined
    @ObservationIgnored private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        status = Self.map(manager.authorizationStatus)
    }

    /// Shows the system prompt the first time; afterwards iOS no longer asks,
    /// so this opens the app's page in Settings instead.
    func requestOrOpenSettings() {
        switch status {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .denied, .granted: Self.openSettings()
        }
    }

    static func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = Self.map(manager.authorizationStatus)
        Task { @MainActor in self.status = status }
    }

    private nonisolated static func map(_ status: CLAuthorizationStatus) -> Status {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways: .granted
        case .denied, .restricted: .denied
        case .notDetermined: .notDetermined
        @unknown default: .denied
        }
    }
}
