import CoreLocation
import Foundation
@testable import Rogers_Event_Assignment

final class FakeLocationService: LocationService, @unchecked Sendable {
    var authorizationStatus: CLAuthorizationStatus = .authorizedWhenInUse
    var location: CLLocation?

    func requestWhenInUseAuthorization() async {
        authorizationStatus = .authorizedWhenInUse
    }

    func currentLocation() async -> CLLocation? {
        location
    }
}
