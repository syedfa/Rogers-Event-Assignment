import Foundation
import SwiftData

/// Every SwiftData read/write in the app goes through this protocol. It is the
/// single source of truth for bookmark state — the event card's heart and the
/// detail screen's bookmark button both call the same `setBookmarked`, so they can
/// never disagree.
protocol EventStore: Sendable {
    /// Inserts new events or updates existing ones by id, preserving `isBookmarked`
    /// on updates. Returns the merged domain events (with correct bookmark flags)
    /// so callers don't need a second round trip to know what's bookmarked.
    @discardableResult
    func upsert(_ events: [Event], fetchedAt: Date) async -> [Event]

    @discardableResult
    func setBookmarked(_ bookmarked: Bool, for eventID: String) async -> Event?

    func event(id: String) async -> Event?

    /// Persisted events whose start date is before `date`, most recent first.
    func past(before date: Date) async -> [Event]

    func bookmarked() async -> [Event]

    /// Deletes non-bookmarked events last fetched before `cutoff`. Bookmarked events
    /// are structurally excluded from the delete predicate — never purged, regardless
    /// of age.
    func prune(olderThan cutoff: Date) async
}

@ModelActor
actor SwiftDataEventStore: EventStore {
    @discardableResult
    func upsert(_ events: [Event], fetchedAt: Date) async -> [Event] {
        let merged = events.map { event -> Event in
            let id = event.id
            let descriptor = FetchDescriptor<PersistedEvent>(predicate: #Predicate { $0.id == id })

            if let existing = try? modelContext.fetch(descriptor).first {
                existing.update(with: event, fetchedAt: fetchedAt)
                return existing.asDomainEvent
            } else {
                let persisted = PersistedEvent(event: event, fetchedAt: fetchedAt)
                modelContext.insert(persisted)
                return persisted.asDomainEvent
            }
        }
        try? modelContext.save()
        return merged
    }

    @discardableResult
    func setBookmarked(_ bookmarked: Bool, for eventID: String) async -> Event? {
        let descriptor = FetchDescriptor<PersistedEvent>(predicate: #Predicate { $0.id == eventID })
        guard let persisted = try? modelContext.fetch(descriptor).first else { return nil }
        persisted.isBookmarked = bookmarked
        try? modelContext.save()
        return persisted.asDomainEvent
    }

    func event(id: String) async -> Event? {
        let descriptor = FetchDescriptor<PersistedEvent>(predicate: #Predicate { $0.id == id })
        return try? modelContext.fetch(descriptor).first?.asDomainEvent
    }

    func past(before date: Date) async -> [Event] {
        // SwiftData's #Predicate macro doesn't reliably translate optional
        // comparisons on `startDate` (both a force-unwrap guard and nil-coalescing
        // either silently match nothing or fail to compile). Filtering in Swift
        // after a plain fetch sidesteps it; the dataset here is small since
        // `prune(olderThan:)` bounds it to ~30 days of non-bookmarked history.
        let descriptor = FetchDescriptor<PersistedEvent>(sortBy: [SortDescriptor(\.startDate, order: .reverse)])
        let all = (try? modelContext.fetch(descriptor)) ?? []
        return all
            .filter { ($0.startDate ?? .distantFuture) < date }
            .map(\.asDomainEvent)
    }

    func bookmarked() async -> [Event] {
        let descriptor = FetchDescriptor<PersistedEvent>(
            predicate: #Predicate { $0.isBookmarked == true },
            sortBy: [SortDescriptor(\.startDate)]
        )
        return (try? modelContext.fetch(descriptor))?.map(\.asDomainEvent) ?? []
    }

    func prune(olderThan cutoff: Date) async {
        let descriptor = FetchDescriptor<PersistedEvent>(
            predicate: #Predicate { $0.isBookmarked == false && $0.fetchedAt < cutoff }
        )
        guard let stale = try? modelContext.fetch(descriptor) else { return }
        for event in stale {
            modelContext.delete(event)
        }
        try? modelContext.save()
    }
}
