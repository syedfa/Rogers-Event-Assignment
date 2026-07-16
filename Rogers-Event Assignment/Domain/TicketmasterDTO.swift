import Foundation

// MARK: - Ticketmaster Discovery API response shapes (subset used by this app)
// Reference: GET /discovery/v2/events.json

struct TicketmasterEventsResponse: Codable, Equatable {
    let embedded: EmbeddedEvents?

    private enum CodingKeys: String, CodingKey {
        case embedded = "_embedded"
    }
}

struct EmbeddedEvents: Codable, Equatable {
    let events: [TicketmasterEventDTO]
}

struct TicketmasterEventDTO: Codable, Equatable {
    let id: String
    let name: String
    let url: String?
    let classifications: [ClassificationDTO]?
    let dates: DatesDTO?
    let images: [ImageDTO]?
    let embedded: EmbeddedVenues?

    private enum CodingKeys: String, CodingKey {
        case id, name, url, classifications, dates, images
        case embedded = "_embedded"
    }
}

struct ClassificationDTO: Codable, Equatable {
    let segment: SegmentDTO?
}

struct SegmentDTO: Codable, Equatable {
    let name: String?
}

struct DatesDTO: Codable, Equatable {
    let start: StartDTO?
    let timezone: String?
}

struct StartDTO: Codable, Equatable {
    let dateTime: String?
    let localDate: String?
    let localTime: String?
}

struct ImageDTO: Codable, Equatable {
    let url: String
    let width: Int
    let height: Int
    let ratio: String?
}

struct EmbeddedVenues: Codable, Equatable {
    let venues: [VenueDTO]?
}

struct VenueDTO: Codable, Equatable {
    let name: String?
    let city: CityDTO?
    let address: AddressDTO?
    let location: LocationDTO?
}

struct CityDTO: Codable, Equatable {
    let name: String?
}

struct AddressDTO: Codable, Equatable {
    let line1: String?
}

struct LocationDTO: Codable, Equatable {
    let latitude: String?
    let longitude: String?
}

// MARK: - Mapping to domain model

extension TicketmasterEventDTO {
    /// Maps a Ticketmaster DTO to the app's domain `Event`. Tolerant of missing
    /// optional fields (image, venue, date) — the API is inconsistent about what's
    /// populated per event, so every field here degrades gracefully to `nil`.
    func toDomain() -> Event {
        Event(
            id: id,
            title: name,
            category: classifications?.first?.segment?.name,
            startDate: Self.parseDate(dates?.start),
            timeZoneIdentifier: dates?.timezone,
            imageURL: Self.bestImage(images).flatMap { URL(string: $0.url) },
            infoURL: url.flatMap { URL(string: $0) },
            venue: embedded?.venues?.first?.toDomain(),
            isBookmarked: false
        )
    }

    /// Prefers a wide (16:9) image at the largest available width; falls back to the
    /// largest image of any ratio if no 16:9 variant exists.
    private static func bestImage(_ images: [ImageDTO]?) -> ImageDTO? {
        guard let images, !images.isEmpty else { return nil }
        let wideImages = images.filter { $0.ratio == "16_9" }
        let candidates = wideImages.isEmpty ? images : wideImages
        return candidates.max(by: { $0.width < $1.width })
    }

    private static func parseDate(_ start: StartDTO?) -> Date? {
        guard let dateTime = start?.dateTime else { return nil }
        return ISO8601DateFormatter().date(from: dateTime)
    }
}

extension VenueDTO {
    func toDomain() -> Venue {
        Venue(
            name: name ?? "Unknown venue",
            address: address?.line1,
            city: city?.name,
            latitude: location?.latitude.flatMap(Double.init),
            longitude: location?.longitude.flatMap(Double.init)
        )
    }
}
