import CoreLocation
import Foundation

protocol LocationService: Sendable {
    var authorizationStatus: CLAuthorizationStatus { get }
    func requestWhenInUseAuthorization() async
    /// One-shot best-effort location fix. Returns `nil` if unauthorized or
    /// unavailable — callers must degrade gracefully (no distance shown), never crash.
    func currentLocation() async -> CLLocation?
}

/// Wraps `CLLocationManager` behind the `LocationService` protocol so ViewModels
/// depend on an abstraction, not Core Location directly, and can be tested with a
/// fake. Delegate callbacks are bridged to `async` via a `CheckedContinuation`.
final class CoreLocationService: NSObject, LocationService, CLLocationManagerDelegate, @unchecked Sendable {
    private let manager: CLLocationManager
    private var locationContinuation: CheckedContinuation<CLLocation?, Never>?
    private var authContinuation: CheckedContinuation<Void, Never>?

    var authorizationStatus: CLAuthorizationStatus {
        manager.authorizationStatus
    }

    override init() {
        manager = CLLocationManager()
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestWhenInUseAuthorization() async {
        guard authorizationStatus == .notDetermined else { return }
        await withCheckedContinuation { continuation in
            authContinuation = continuation
            manager.requestWhenInUseAuthorization()
        }
    }

    func currentLocation() async -> CLLocation? {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            return nil
        }
        return await withCheckedContinuation { continuation in
            locationContinuation = continuation
            manager.requestLocation()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authContinuation?.resume()
        authContinuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        locationContinuation?.resume(returning: locations.last)
        locationContinuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationContinuation?.resume(returning: nil)
        locationContinuation = nil
    }
}
