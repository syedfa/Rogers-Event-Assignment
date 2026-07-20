import Foundation
@testable import Rogers_Event_Assignment
import Testing

struct EventsRepositoryTests {
    @MainActor
    @Test func cacheMissThenSuccessEmitsLoadingThenLoaded() async {
        let clock = TestClock()
        let network = MockNetworkService { _ in .success(Data(TicketmasterFixtures.singleFullEvent.utf8)) }
        let (repository, _) = makeEventsRepository(network: network, clock: clock)
        let collector = StateCollector<LoadState<[Event]>>()

        await repository.fetchEvents(for: TicketmasterFixtures.sampleEventStartDate, near: nil) { collector.record($0) }

        #expect(collector.values.count == 2)
        #expect(collector.values[0].isLoading)
        guard case .loaded(let events) = collector.values[1] else {
            Issue.record("Expected .loaded, got \(collector.values[1])")
            return
        }
        #expect(events.first?.id == "abc123")
    }

    /// Core test 1/3 (assignment spec): proves the repository's
    /// stale-while-revalidate contract — a cache hit emits immediately, then
    /// the repository *always* revalidates over the network and emits again,
    /// rather than treating a fresh cache as a reason to skip the network.
    @MainActor
    @Test func cacheHitEmitsCachedResultThenRefreshedResult() async {
        let clock = TestClock()
        let network = MockNetworkService { _ in .success(Data(TicketmasterFixtures.singleFullEvent.utf8)) }
        let (repository, _) = makeEventsRepository(network: network, clock: clock)
        let fetchDate = TicketmasterFixtures.sampleEventStartDate

        // Prime the cache with a first fetch.
        await repository.fetchEvents(for: fetchDate, near: nil) { _ in }

        let collector = StateCollector<LoadState<[Event]>>()
        await repository.fetchEvents(for: fetchDate, near: nil) { collector.record($0) }

        #expect(collector.values.count == 2)
        guard case .loaded = collector.values[0] else {
            Issue.record("Expected cached .loaded first, got \(collector.values[0])")
            return
        }
        guard case .loaded = collector.values[1] else {
            Issue.record("Expected refreshed .loaded second, got \(collector.values[1])")
            return
        }
    }

    @MainActor
    @Test func networkFailureWithNoCacheEmitsFailedWithNoPreviousValue() async {
        let clock = TestClock()
        let network = MockNetworkService { _ in .failure(.network) }
        let (repository, _) = makeEventsRepository(network: network, clock: clock)
        let collector = StateCollector<LoadState<[Event]>>()

        await repository.fetchEvents(for: clock.now(), near: nil) { collector.record($0) }

        guard case .failed(let error, let previous) = collector.values.last else {
            Issue.record("Expected .failed, got \(String(describing: collector.values.last))")
            return
        }
        #expect(error == .network)
        #expect(previous == nil)
    }

    @MainActor
    @Test func networkFailureWithCacheEmitsFailedWithPreviousValue() async {
        let clock = TestClock()
        let callCount = Counter()
        let network = MockNetworkService { _ in
            callCount.increment() == 1
                ? .success(Data(TicketmasterFixtures.singleFullEvent.utf8))
                : .failure(.network)
        }
        let (repository, _) = makeEventsRepository(network: network, clock: clock)
        let fetchDate = TicketmasterFixtures.sampleEventStartDate

        await repository.fetchEvents(for: fetchDate, near: nil) { _ in }

        let collector = StateCollector<LoadState<[Event]>>()
        await repository.fetchEvents(for: fetchDate, near: nil) { collector.record($0) }

        guard case .failed(let error, let previous) = collector.values.last else {
            Issue.record("Expected .failed, got \(String(describing: collector.values.last))")
            return
        }
        #expect(error == .network)
        #expect(previous?.first?.id == "abc123")
    }

    @MainActor
    @Test func missingAPIKeyEmitsUnauthorizedImmediatelyWithoutNetworkCall() async {
        let clock = TestClock()
        let callCount = Counter()
        let network = MockNetworkService { _ in
            callCount.increment()
            return .failure(.network)
        }
        let (repository, _) = makeEventsRepository(network: network, clock: clock, apiKey: nil)
        let collector = StateCollector<LoadState<[Event]>>()

        await repository.fetchEvents(for: clock.now(), near: nil) { collector.record($0) }

        #expect(collector.values.count == 1)
        #expect(collector.values.first?.error == .unauthorized)
        #expect(callCount.value == 0)
    }

    /// Regression test: Ticketmaster's `startDateTime`/`endDateTime` params aren't
    /// reliably honored server-side for some catalog entries — a request for one day
    /// can come back with events dated on a completely different day. Without a
    /// client-side check, every day in the date strip would show the same stale
    /// results. `TestClock`'s default "now" (1970 + 1.7B seconds ≈ 2023-11-14) is
    /// nowhere near the fixture's 2026-08-01 event, so requesting "today" must
    /// exclude it even though the server returned it.
    @MainActor
    @Test func fetchEventsExcludesEventsOutsideTheRequestedDayWindowEvenIfServerReturnsThem() async {
        let clock = TestClock()
        let network = MockNetworkService { _ in .success(Data(TicketmasterFixtures.singleFullEvent.utf8)) }
        let (repository, _) = makeEventsRepository(network: network, clock: clock)
        let collector = StateCollector<LoadState<[Event]>>()

        await repository.fetchEvents(for: clock.now(), near: nil) { collector.record($0) }

        guard case .loaded(let events) = collector.values.last else {
            Issue.record("Expected .loaded, got \(String(describing: collector.values.last))")
            return
        }
        #expect(events.isEmpty)
    }

    @Test func successfulFetchUpsertsIntoEventStore() async {
        let clock = TestClock()
        let network = MockNetworkService { _ in .success(Data(TicketmasterFixtures.singleFullEvent.utf8)) }
        let (repository, store) = makeEventsRepository(network: network, clock: clock)

        await repository.fetchEvents(for: TicketmasterFixtures.sampleEventStartDate, near: nil) { _ in }

        #expect(await store.event(id: "abc123") != nil)
    }

    @Test func fetchEventsFiltersOutEventsWithoutAVenue() async {
        let clock = TestClock()
        let network = MockNetworkService { _ in .success(Data(TicketmasterFixtures.mixedVenueAndNoVenueEvents.utf8)) }
        let (repository, store) = makeEventsRepository(network: network, clock: clock)

        await repository.fetchEvents(for: TicketmasterFixtures.sampleEventStartDate, near: nil) { _ in }

        #expect(await store.event(id: "abc123") != nil)
        #expect(await store.event(id: "digital456") == nil)
    }
}
