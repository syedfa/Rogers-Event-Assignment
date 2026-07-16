import CoreLocation
import Foundation

/// Formats the distance from the user to an event's venue using
/// `MeasurementFormatter`, which automatically picks km vs. mi based on locale —
/// no manual unit-conversion logic, no hardcoded "mi" strings.
enum DistanceFormatter {
    static func string(from userLocation: CLLocation?, to venue: Venue?, locale: Locale = .current) -> String? {
        guard let userLocation,
              let venue,
              let latitude = venue.latitude,
              let longitude = venue.longitude else {
            return nil
        }

        let venueLocation = CLLocation(latitude: latitude, longitude: longitude)
        let meters = userLocation.distance(from: venueLocation)
        let measurement = Measurement(value: meters, unit: UnitLength.meters)

        let formatter = MeasurementFormatter()
        formatter.locale = locale
        formatter.unitOptions = .naturalScale
        formatter.unitStyle = .medium
        formatter.numberFormatter.maximumFractionDigits = 1
        return formatter.string(from: measurement)
    }
}
