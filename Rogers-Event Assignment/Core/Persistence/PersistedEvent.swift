import Foundation
import SwiftData

/// SwiftData model backing both requirements the assignment calls out: it's the
/// "last-fetched events" cache and the durable bookmark store. Confined to the
/// Persistence layer — nothing above `EventStore` ever sees this type directly.
@Model
final class PersistedEvent {
    @Attribute(.unique) var id: String
    var title: String
    var category: String?
    var startDate: Date?
    var timeZoneIdentifier: String?
    var imageURLString: String?
    var infoURLString: String?
    var venueName: String?
    var venueAddress: String?
    var venueCity: String?
    var venueLatitude: Double?
    var venueLongitude: Double?
    var isBookmarked: Bool
    var fetchedAt: Date

    init(event: Event, fetchedAt: Date, isBookmarked: Bool = false) {
        self.id = event.id
        self.title = event.title
        self.category = event.category
        self.startDate = event.startDate
        self.timeZoneIdentifier = event.timeZoneIdentifier
        self.imageURLString = event.imageURL?.absoluteString
        self.infoURLString = event.infoURL?.absoluteString
        self.venueName = event.venue?.name
        self.venueAddress = event.venue?.address
        self.venueCity = event.venue?.city
        self.venueLatitude = event.venue?.latitude
        self.venueLongitude = event.venue?.longitude
        self.isBookmarked = isBookmarked
        self.fetchedAt = fetchedAt
    }

    /// Applies fresh network data on top of an existing record, deliberately leaving
    /// `isBookmarked` untouched — a re-fetch must never silently drop a bookmark.
    func update(with event: Event, fetchedAt: Date) {
        title = event.title
        category = event.category
        startDate = event.startDate
        timeZoneIdentifier = event.timeZoneIdentifier
        imageURLString = event.imageURL?.absoluteString
        infoURLString = event.infoURL?.absoluteString
        venueName = event.venue?.name
        venueAddress = event.venue?.address
        venueCity = event.venue?.city
        venueLatitude = event.venue?.latitude
        venueLongitude = event.venue?.longitude
        self.fetchedAt = fetchedAt
    }

    var asDomainEvent: Event {
        let venue: Venue?
        if let venueName {
            venue = Venue(
                name: venueName,
                address: venueAddress,
                city: venueCity,
                latitude: venueLatitude,
                longitude: venueLongitude
            )
        } else {
            venue = nil
        }

        return Event(
            id: id,
            title: title,
            category: category,
            startDate: startDate,
            timeZoneIdentifier: timeZoneIdentifier,
            imageURL: imageURLString.flatMap(URL.init(string:)),
            infoURL: infoURLString.flatMap(URL.init(string:)),
            venue: venue,
            isBookmarked: isBookmarked
        )
    }
}
