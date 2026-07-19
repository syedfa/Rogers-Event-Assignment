import Foundation

/// The two ways the Home screen can slice events. `.explore` is served by the
/// network (through `EventsRepository`'s cache) and is filtered to the selected
/// date; `.bookmarked` is served entirely from `EventStore` (SwiftData), works
/// offline, and always shows every saved event regardless of the selected date.
enum EventSegment: String, CaseIterable, Identifiable, Sendable {
    case explore
    case bookmarked

    var id: String { rawValue }

    var title: String {
        switch self {
        case .explore: return "Explore"
        case .bookmarked: return "Saved"
        }
    }
}
