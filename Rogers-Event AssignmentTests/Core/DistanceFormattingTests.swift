import CoreLocation
@testable import Rogers_Event_Assignment
import Testing

struct DistanceFormattingTests {
    @Test func returnsNilWhenUserLocationIsMissing() {
        let venue = Venue(name: "V", address: nil, city: nil, latitude: 43.0, longitude: -79.0)
        #expect(DistanceFormatter.string(from: nil, to: venue) == nil)
    }

    @Test func returnsNilWhenVenueHasNoCoordinates() {
        let location = CLLocation(latitude: 43.0, longitude: -79.0)
        let venue = Venue(name: "V", address: nil, city: nil, latitude: nil, longitude: nil)
        #expect(DistanceFormatter.string(from: location, to: venue) == nil)
    }

    @Test func returnsNilWhenVenueIsMissing() {
        let location = CLLocation(latitude: 43.0, longitude: -79.0)
        #expect(DistanceFormatter.string(from: location, to: nil) == nil)
    }

    @Test func usesImperialUnitsForUSLocale() {
        let location = CLLocation(latitude: 43.6426, longitude: -79.3871)
        let venue = Venue(name: "V", address: nil, city: nil, latitude: 43.70, longitude: -79.40)
        let result = DistanceFormatter.string(from: location, to: venue, locale: Locale(identifier: "en_US"))
        #expect(result?.contains("mi") == true)
    }

    @Test func usesMetricUnitsForCanadianLocale() {
        let location = CLLocation(latitude: 43.6426, longitude: -79.3871)
        let venue = Venue(name: "V", address: nil, city: nil, latitude: 43.70, longitude: -79.40)
        let result = DistanceFormatter.string(from: location, to: venue, locale: Locale(identifier: "en_CA"))
        #expect(result?.contains("km") == true)
    }
}
