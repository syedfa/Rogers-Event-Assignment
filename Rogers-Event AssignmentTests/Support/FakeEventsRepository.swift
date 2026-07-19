import CoreLocation
import Foundation
@testable import Rogers_Event_Assignment

/// Fake `EventsRepository` for ViewModel tests, so those tests exercise
/// `HomeViewModel`'s segment-routing logic without pulling in real caching or
/// network behavior (that's `EventsRepositoryTests`' job).
final class FakeEventsRepository: EventsRepository, @unchecked Sendable {
    var fetchEventsHandler: (@Sendable (Date, CLLocation?) async -> LoadState<[Event]>)?
    private(set) var fetchCallCount = 0
    private(set) var lastFetchDate: Date?
    private(set) var allFetchDates: [Date] = []

    func fetchEvents(
        for date: Date,
        near location: CLLocation?,
        onUpdate: @escaping @MainActor @Sendable (LoadState<[Event]>) -> Void
    ) async {
        fetchCallCount += 1
        lastFetchDate = date
        allFetchDates.append(date)
        let state = await fetchEventsHandler?(date, location) ?? .loaded([])
        await onUpdate(state)
    }

    func refreshUpcomingNearby(near location: CLLocation?) async {}
}
