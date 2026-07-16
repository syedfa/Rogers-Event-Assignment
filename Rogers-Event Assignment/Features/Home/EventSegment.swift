import Foundation

/// The three ways the Home screen can slice events. `.upcoming` is served by the
/// network (through `EventsRepository`'s cache); `.past` and `.bookmarked` are
/// served entirely from `EventStore` (SwiftData) and work offline.
enum EventSegment: String, CaseIterable, Identifiable, Sendable {
    case upcoming
    case past
    case bookmarked

    var id: String { rawValue }

    var title: String {
        switch self {
        case .upcoming: return "Upcoming"
        case .past: return "Past"
        case .bookmarked: return "Saved"
        }
    }
}
