import CoreLocation
import Foundation
@testable import Rogers_Event_Assignment

/// Fake `EventsRepository` for ViewModel tests, so those tests exercise
/// `HomeViewModel`'s segment-routing logic without pulling in real caching or
/// network behavior (that's `EventsRepositoryTests`' job).
final class FakeEventsRepository: EventsRepository, @unchecked Sendable {
    var fetchUpcomingHandler: (@Sendable (Date, CLLocation?) async -> LoadState<[Event]>)?
    var fetchPastHandler: (@Sendable (Date, CLLocation?) async -> LoadState<[Event]>)?
    private(set) var fetchCallCount = 0
    private(set) var fetchPastCallCount = 0
    private(set) var lastFetchUpcomingDate: Date?
    private(set) var lastFetchPastDate: Date?
    private(set) var allFetchUpcomingDates: [Date] = []

    func fetchUpcoming(
        for date: Date,
        near location: CLLocation?,
        onUpdate: @escaping @MainActor @Sendable (LoadState<[Event]>) -> Void
    ) async {
        fetchCallCount += 1
        lastFetchUpcomingDate = date
        allFetchUpcomingDates.append(date)
        let state = await fetchUpcomingHandler?(date, location) ?? .loaded([])
        await onUpdate(state)
    }

    func fetchPast(
        for date: Date,
        near location: CLLocation?,
        onUpdate: @escaping @MainActor @Sendable (LoadState<[Event]>) -> Void
    ) async {
        fetchPastCallCount += 1
        lastFetchPastDate = date
        let state = await fetchPastHandler?(date, location) ?? .loaded([])
        await onUpdate(state)
    }

    func refreshUpcomingNearby(near location: CLLocation?) async {}
}
