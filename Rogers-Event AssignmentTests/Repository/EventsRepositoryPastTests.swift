import Foundation
@testable import Rogers_Event_Assignment
import Testing

struct EventsRepositoryPastTests {
    @MainActor
    @Test func fetchPastCacheMissThenSuccessEmitsLoadingThenLoaded() async {
        // "Now" must be after the fixture event's day for it to count as occurred.
        let clock = TestClock(date: Date(timeIntervalSince1970: 1_800_000_000))
        let network = MockNetworkService { _ in .success(Data(TicketmasterFixtures.singleFullEvent.utf8)) }
        let (repository, _) = makeEventsRepository(network: network, clock: clock)
        let collector = StateCollector<LoadState<[Event]>>()

        await repository.fetchPast(for: TicketmasterFixtures.sampleEventStartDate, near: nil) { collector.record($0) }

        #expect(collector.values.count == 2)
        #expect(collector.values[0].isLoading)
        guard case .loaded(let events) = collector.values[1] else {
            Issue.record("Expected .loaded, got \(collector.values[1])")
            return
        }
        #expect(events.first?.id == "abc123")
    }

    @MainActor
    @Test func fetchPastEmitsLocallyCachedResultBeforeNetworkResult() async {
        let calendar = Calendar.current
        let referenceDay = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
        let noon = referenceDay.addingTimeInterval(12 * 3600)
        let clock = TestClock(date: noon)
        let network = MockNetworkService { _ in .success(Data(TicketmasterFixtures.emptyResponse.utf8)) }
        let (repository, store) = makeEventsRepository(network: network, clock: clock)
        let cachedEvent = Event(
            id: "cached1",
            title: "Old show",
            category: nil,
            startDate: referenceDay.addingTimeInterval(3600), // 1am the same day, before "now"
            timeZoneIdentifier: nil,
            imageURL: nil,
            infoURL: nil,
            venue: nil,
            isBookmarked: false
        )
        await store.upsert([cachedEvent], fetchedAt: clock.now())
        let collector = StateCollector<LoadState<[Event]>>()

        await repository.fetchPast(for: noon, near: nil) { collector.record($0) }

        guard case .loaded(let firstEvents) = collector.values.first else {
            Issue.record("Expected cached .loaded first, got \(String(describing: collector.values.first))")
            return
        }
        #expect(firstEvents.map(\.id) == ["cached1"])
    }

    @MainActor
    @Test func fetchPastFiltersOutEventsWithoutAVenue() async {
        let clock = TestClock(date: Date(timeIntervalSince1970: 1_800_000_000))
        let network = MockNetworkService { _ in .success(Data(TicketmasterFixtures.mixedVenueAndNoVenueEvents.utf8)) }
        let (repository, store) = makeEventsRepository(network: network, clock: clock)

        await repository.fetchPast(for: TicketmasterFixtures.sampleEventStartDate, near: nil) { _ in }

        #expect(await store.event(id: "abc123") != nil)
        #expect(await store.event(id: "digital456") == nil)
    }

    /// Core of the reported bug: selecting a future date on the Past tab must never
    /// show anything (nothing could have started yet) — and shouldn't even hit the
    /// network to find out.
    @MainActor
    @Test func fetchPastReturnsEmptyForAFutureDateWithoutANetworkCall() async {
        let clock = TestClock(date: Date(timeIntervalSince1970: 1_700_000_000))
        let callCount = Counter()
        let network = MockNetworkService { _ in
            callCount.increment()
            return .success(Data(TicketmasterFixtures.emptyResponse.utf8))
        }
        let (repository, _) = makeEventsRepository(network: network, clock: clock)
        let futureDate = clock.now().addingTimeInterval(30 * 24 * 3600)
        let collector = StateCollector<LoadState<[Event]>>()

        await repository.fetchPast(for: futureDate, near: nil) { collector.record($0) }

        guard case .loaded(let events) = collector.values.last else {
            Issue.record("Expected .loaded, got \(String(describing: collector.values.last))")
            return
        }
        #expect(events.isEmpty)
        #expect(callCount.value == 0)
    }

    /// Selecting today's day on the Past tab shows events that have already
    /// started today (an event counts as "past" once it's underway, not only once
    /// the whole day has elapsed).
    @MainActor
    @Test func fetchPastIncludesEventsEarlierTodayThatHaveAlreadyStarted() async {
        let calendar = Calendar.current
        let referenceDay = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
        let noon = referenceDay.addingTimeInterval(12 * 3600)
        let clock = TestClock(date: noon)
        let network = MockNetworkService { _ in .success(Data(TicketmasterFixtures.emptyResponse.utf8)) }
        let (repository, store) = makeEventsRepository(network: network, clock: clock)
        let alreadyStarted = Event(
            id: "earlier-today",
            title: "This morning's show",
            category: nil,
            startDate: referenceDay.addingTimeInterval(8 * 3600), // 8am, before "now" (noon)
            timeZoneIdentifier: nil,
            imageURL: nil,
            infoURL: nil,
            venue: nil,
            isBookmarked: false
        )
        await store.upsert([alreadyStarted], fetchedAt: clock.now())
        let collector = StateCollector<LoadState<[Event]>>()

        await repository.fetchPast(for: noon, near: nil) { collector.record($0) }

        #expect(collector.values.contains { $0.currentValue?.map(\.id) == ["earlier-today"] })
    }

    /// The flip side of the above: events later today that haven't started yet
    /// must not appear — "Past" only ever shows what's already underway or over.
    @MainActor
    @Test func fetchPastExcludesEventsLaterTodayThatHaveNotStartedYet() async {
        let calendar = Calendar.current
        let referenceDay = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
        let noon = referenceDay.addingTimeInterval(12 * 3600)
        let clock = TestClock(date: noon)
        let network = MockNetworkService { _ in .success(Data(TicketmasterFixtures.emptyResponse.utf8)) }
        let (repository, store) = makeEventsRepository(network: network, clock: clock)
        let notYetStarted = Event(
            id: "later-today",
            title: "Tonight's show",
            category: nil,
            startDate: referenceDay.addingTimeInterval(20 * 3600), // 8pm, after "now" (noon)
            timeZoneIdentifier: nil,
            imageURL: nil,
            infoURL: nil,
            venue: nil,
            isBookmarked: false
        )
        await store.upsert([notYetStarted], fetchedAt: clock.now())
        let collector = StateCollector<LoadState<[Event]>>()

        await repository.fetchPast(for: noon, near: nil) { collector.record($0) }

        #expect(collector.values.allSatisfy { $0.currentValue?.isEmpty ?? true })
    }
}
