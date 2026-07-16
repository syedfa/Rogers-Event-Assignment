import Foundation

/// Domain model for an event. Everything above the `Persistence` layer works with
/// this type, never with the SwiftData `@Model` or the Ticketmaster DTOs directly.
struct Event: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let category: String?
    let startDate: Date?
    let timeZoneIdentifier: String?
    let imageURL: URL?
    let infoURL: URL?
    let venue: Venue?
    var isBookmarked: Bool
}

struct Venue: Equatable, Sendable {
    let name: String
    let address: String?
    let city: String?
    let latitude: Double?
    let longitude: Double?
}
