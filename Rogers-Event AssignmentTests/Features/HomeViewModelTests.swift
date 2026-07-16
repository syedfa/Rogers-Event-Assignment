import CoreLocation
import Foundation
@testable import Rogers_Event_Assignment
import Testing

@MainActor
struct HomeViewModelTests {
    private func sampleEvent(
        id: String,
        startDate: Date? = Date(),
        venue: Venue? = nil,
        isBookmarked: Bool = false
    ) -> Event {
        Event(
            id: id,
            title: "Event \(id)",
            category: nil,
            startDate: startDate,
            timeZoneIdentifier: nil,
            imageURL: nil,
            infoURL: nil,
            venue: venue,
            isBookmarked: isBookmarked
        )
    }

    private func venue(latitude: Double, longitude: Double) -> Venue {
        Venue(name: "Venue", address: nil, city: nil, latitude: latitude, longitude: longitude)
    }

    private func makeViewModel(
        repository: EventsRepository,
        eventStore: EventStore
    ) -> HomeViewModel {
        HomeViewModel(
            repository: repository,
            eventStore: eventStore,
            locationService: FakeLocationService(),
            referenceDate: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    /// Regression test: the Simulator has no GPS fix unless one is manually set, so
    /// `currentLocation()` returns `nil` even when authorized. Without a fallback,
    /// every "Upcoming"/"Past" query would run unfiltered by geography — confirmed
    /// via direct API testing to return effectively zero real, correctly-dated
    /// local events. `HomeViewModel` must substitute `DefaultLocation.fallback`.
    @Test func fetchUsesDefaultLocationWhenNoLiveLocationIsAvailable() async {
        let repository = FakeEventsRepository()
        let locations = StateCollector<CLLocation?>()
        repository.fetchUpcomingHandler = { _, location in
            locations.record(location)
            return .loaded([])
        }
        let store = SwiftDataEventStore(modelContainer: ModelContainerFactory.make(inMemory: true))
        let locationService = FakeLocationService()
        locationService.location = nil
        let viewModel = HomeViewModel(
            repository: repository,
            eventStore: store,
            locationService: locationService,
            referenceDate: Date(timeIntervalSince1970: 1_700_000_000)
        )

        await viewModel.onAppear()

        #expect(locations.values.first ?? nil != nil)
    }

    @Test func upcomingSegmentIsServedByRepositoryNotEventStore() async {
        let repository = FakeEventsRepository()
        let networkEvent = sampleEvent(id: "net1")
        repository.fetchUpcomingHandler = { _, _ in .loaded([networkEvent]) }
        let store = SwiftDataEventStore(modelContainer: ModelContainerFactory.make(inMemory: true))
        let viewModel = makeViewModel(repository: repository, eventStore: store)

        await viewModel.onAppear()

        #expect(repository.fetchCallCount == 1)
        #expect(viewModel.state.currentValue?.map(\.id) == ["net1"])
    }

    /// Ticketmaster's date-range filtering is reliable for today/near-future
    /// queries but not backward-looking ones (confirmed via live testing against
    /// the real API). The only realistic way "Past" ever has real data for a day is
    /// if it was already fetched while still current — so the date strip's whole
    /// visible range must be warmed, not just the selected day. `HomeView` fires
    /// this from its own concurrent `.task` (see `prefetchDateStripDays()`'s doc),
    /// not from `onAppear()`, so it's called explicitly here too.
    @Test func prefetchDateStripDaysWarmsEveryDayInTheStrip() async {
        let repository = FakeEventsRepository()
        let store = SwiftDataEventStore(modelContainer: ModelContainerFactory.make(inMemory: true))
        let viewModel = makeViewModel(repository: repository, eventStore: store)

        await viewModel.onAppear()
        await viewModel.prefetchDateStripDays()

        let requestedDays = Set(repository.allFetchUpcomingDates.map { Calendar.current.startOfDay(for: $0) })
        let expectedDays = Set(viewModel.dateStripDays.map { Calendar.current.startOfDay(for: $0) })
        #expect(requestedDays == expectedDays)
    }

    @Test func pastSegmentIsServedByRepository() async {
        let repository = FakeEventsRepository()
        let pastEvent = sampleEvent(id: "past1", startDate: Date(timeIntervalSince1970: 1))
        repository.fetchPastHandler = { _, _ in .loaded([pastEvent]) }
        let store = SwiftDataEventStore(modelContainer: ModelContainerFactory.make(inMemory: true))

        let viewModel = makeViewModel(repository: repository, eventStore: store)
        await viewModel.select(segment: .past)

        #expect(repository.fetchPastCallCount == 1)
        #expect(repository.fetchCallCount == 0)
        #expect(viewModel.state.currentValue?.map(\.id) == ["past1"])
    }

    @Test func bookmarkedSegmentReadsFromEventStoreNotRepository() async {
        let repository = FakeEventsRepository()
        let store = SwiftDataEventStore(modelContainer: ModelContainerFactory.make(inMemory: true))
        await store.upsert([sampleEvent(id: "e1")], fetchedAt: Date())
        await store.setBookmarked(true, for: "e1")

        let viewModel = makeViewModel(repository: repository, eventStore: store)
        await viewModel.select(segment: .bookmarked)

        #expect(repository.fetchCallCount == 0)
        #expect(viewModel.state.currentValue?.map(\.id) == ["e1"])
    }

    /// Regression test: bookmarking from the event detail screen writes straight to
    /// `EventStore`, bypassing `HomeViewModel` entirely (unlike the card's heart,
    /// which calls `HomeViewModel.toggleBookmark`). This proves reloading afterward
    /// — what `HomeView`'s `.sheet(onDismiss:)` now does — picks the change back up,
    /// which is the underlying mechanism the dismiss-triggered reload relies on.
    @Test func reloadingAfterDetailScreenBookmarkReflectsTheUpdatedState() async {
        let repository = FakeEventsRepository()
        let store = SwiftDataEventStore(modelContainer: ModelContainerFactory.make(inMemory: true))
        let event = sampleEvent(id: "e1")
        await store.upsert([event], fetchedAt: Date())
        // Mirrors how the real DefaultEventsRepository behaves: every fetch re-reads
        // current truth from EventStore rather than returning a fixed snapshot.
        repository.fetchUpcomingHandler = { _, _ in
            let current = await store.event(id: "e1")
            return .loaded(current.map { [$0] } ?? [])
        }

        let viewModel = makeViewModel(repository: repository, eventStore: store)
        await viewModel.onAppear()
        #expect(viewModel.state.currentValue?.first?.isBookmarked == false)

        // Simulate opening the detail screen and bookmarking there — a separate
        // ViewModel instance sharing the same EventStore, exactly as HomeView wires
        // makeDetailViewModel(event).
        let detailViewModel = EventDetailViewModel(event: event, eventStore: store, locationService: FakeLocationService())
        await detailViewModel.toggleBookmark()
        #expect(detailViewModel.event.isBookmarked == true)

        // Simulate the sheet's onDismiss reload.
        await viewModel.load()

        #expect(viewModel.state.currentValue?.first?.isBookmarked == true)
    }

    @Test func selectingDateReloadsWhileOnUpcomingSegment() async {
        let repository = FakeEventsRepository()
        let store = SwiftDataEventStore(modelContainer: ModelContainerFactory.make(inMemory: true))
        let viewModel = makeViewModel(repository: repository, eventStore: store)

        await viewModel.select(date: Date(timeIntervalSince1970: 1_800_000_000))

        #expect(repository.fetchCallCount == 1)
    }

    /// Regression test for the reported bug: selecting a date on the Past tab must
    /// re-query for that specific day (a separate fetchPast call per day, mirroring
    /// Upcoming), not silently do nothing.
    @Test func selectingDateReloadsWhileOnPastSegment() async {
        let repository = FakeEventsRepository()
        let store = SwiftDataEventStore(modelContainer: ModelContainerFactory.make(inMemory: true))
        let viewModel = makeViewModel(repository: repository, eventStore: store)
        let pickedDate = Date(timeIntervalSince1970: 1_800_000_000)

        await viewModel.select(segment: .past)
        await viewModel.select(date: pickedDate)

        // Once for select(segment:), once for select(date:).
        #expect(repository.fetchPastCallCount == 2)
        #expect(repository.fetchCallCount == 0)
        #expect(repository.lastFetchPastDate == Calendar.current.startOfDay(for: pickedDate))
    }

    @Test func selectingDateDoesNotAffectBookmarkedSegment() async {
        let repository = FakeEventsRepository()
        let store = SwiftDataEventStore(modelContainer: ModelContainerFactory.make(inMemory: true))
        let viewModel = makeViewModel(repository: repository, eventStore: store)

        await viewModel.select(segment: .bookmarked)
        await viewModel.select(date: Date(timeIntervalSince1970: 1_800_000_000))

        #expect(repository.fetchCallCount == 0)
        #expect(repository.fetchPastCallCount == 0)
    }

    @Test func toggleBookmarkPersistsAndReloadsCurrentSegment() async {
        let repository = FakeEventsRepository()
        let store = SwiftDataEventStore(modelContainer: ModelContainerFactory.make(inMemory: true))
        let event = sampleEvent(id: "e1")
        await store.upsert([event], fetchedAt: Date())

        let viewModel = makeViewModel(repository: repository, eventStore: store)
        await viewModel.select(segment: .bookmarked)
        #expect(viewModel.state.currentValue?.isEmpty == true)

        await viewModel.toggleBookmark(for: event)

        #expect(await store.event(id: "e1")?.isBookmarked == true)
        #expect(viewModel.state.currentValue?.map(\.id) == ["e1"])
    }

    @Test func togglingBookmarkOffRemovesEventFromBookmarkedSegment() async {
        let repository = FakeEventsRepository()
        let store = SwiftDataEventStore(modelContainer: ModelContainerFactory.make(inMemory: true))
        await store.upsert([sampleEvent(id: "e1")], fetchedAt: Date())
        await store.setBookmarked(true, for: "e1")
        let bookmarkedEvent = sampleEvent(id: "e1", isBookmarked: true)

        let viewModel = makeViewModel(repository: repository, eventStore: store)
        await viewModel.select(segment: .bookmarked)
        #expect(viewModel.state.currentValue?.map(\.id) == ["e1"])

        await viewModel.toggleBookmark(for: bookmarkedEvent)

        #expect(viewModel.state.currentValue?.isEmpty == true)
    }

    @Test func distanceTextIsNilWithoutALiveLocation() async {
        let repository = FakeEventsRepository()
        let store = SwiftDataEventStore(modelContainer: ModelContainerFactory.make(inMemory: true))
        let locationService = FakeLocationService()
        locationService.location = nil
        let viewModel = HomeViewModel(
            repository: repository,
            eventStore: store,
            locationService: locationService,
            referenceDate: Date(timeIntervalSince1970: 1_700_000_000)
        )
        await viewModel.onAppear()

        let event = sampleEvent(id: "e1", venue: venue(latitude: 43.66, longitude: -79.38))

        #expect(viewModel.distanceText(for: event) == nil)
    }

    /// Regression: distance must come only from a real device location, never from
    /// `DefaultLocation.fallback` — that fallback exists purely to bias the network
    /// query, and showing a number computed from it would be misleading.
    @Test func distanceTextReflectsOnlyTheRealDeviceLocation() async {
        let repository = FakeEventsRepository()
        let store = SwiftDataEventStore(modelContainer: ModelContainerFactory.make(inMemory: true))
        let locationService = FakeLocationService()
        locationService.location = CLLocation(latitude: 43.6532, longitude: -79.3832)
        let viewModel = HomeViewModel(
            repository: repository,
            eventStore: store,
            locationService: locationService,
            referenceDate: Date(timeIntervalSince1970: 1_700_000_000)
        )
        await viewModel.onAppear()

        let nearby = sampleEvent(id: "e1", venue: venue(latitude: 43.66, longitude: -79.38))

        #expect(viewModel.distanceText(for: nearby) != nil)
    }

    @Test func bookmarkedSegmentSortsNearestToFarthestWhenLocationIsAvailable() async {
        let repository = FakeEventsRepository()
        let store = SwiftDataEventStore(modelContainer: ModelContainerFactory.make(inMemory: true))
        let near = sampleEvent(id: "near", venue: venue(latitude: 43.66, longitude: -79.38))
        let medium = sampleEvent(id: "medium", venue: venue(latitude: 43.75, longitude: -79.40))
        let far = sampleEvent(id: "far", venue: venue(latitude: 45.50, longitude: -73.57))
        // Inserted out of distance order on purpose.
        await store.upsert([far, near, medium], fetchedAt: Date())
        for event in [far, near, medium] {
            await store.setBookmarked(true, for: event.id)
        }

        let locationService = FakeLocationService()
        locationService.location = CLLocation(latitude: 43.6532, longitude: -79.3832)
        let viewModel = HomeViewModel(
            repository: repository,
            eventStore: store,
            locationService: locationService,
            referenceDate: Date(timeIntervalSince1970: 1_700_000_000)
        )
        await viewModel.onAppear()
        await viewModel.select(segment: .bookmarked)

        #expect(viewModel.state.currentValue?.map(\.id) == ["near", "medium", "far"])
    }

    @Test func upcomingSegmentSortsNearestToFarthestWhenLocationIsAvailable() async {
        let repository = FakeEventsRepository()
        let near = sampleEvent(id: "near", venue: venue(latitude: 43.66, longitude: -79.38))
        let far = sampleEvent(id: "far", venue: venue(latitude: 45.50, longitude: -73.57))
        // Repository returns farthest first — HomeViewModel must reorder.
        repository.fetchUpcomingHandler = { _, _ in .loaded([far, near]) }
        let store = SwiftDataEventStore(modelContainer: ModelContainerFactory.make(inMemory: true))

        let locationService = FakeLocationService()
        locationService.location = CLLocation(latitude: 43.6532, longitude: -79.3832)
        let viewModel = HomeViewModel(
            repository: repository,
            eventStore: store,
            locationService: locationService,
            referenceDate: Date(timeIntervalSince1970: 1_700_000_000)
        )

        await viewModel.onAppear()

        #expect(viewModel.state.currentValue?.map(\.id) == ["near", "far"])
    }

    @Test func sortingLeavesOrderUnchangedWithoutALiveLocation() async {
        let repository = FakeEventsRepository()
        let far = sampleEvent(id: "far", venue: venue(latitude: 45.50, longitude: -73.57))
        let near = sampleEvent(id: "near", venue: venue(latitude: 43.66, longitude: -79.38))
        repository.fetchUpcomingHandler = { _, _ in .loaded([far, near]) }
        let store = SwiftDataEventStore(modelContainer: ModelContainerFactory.make(inMemory: true))
        let locationService = FakeLocationService()
        locationService.location = nil
        let viewModel = HomeViewModel(
            repository: repository,
            eventStore: store,
            locationService: locationService,
            referenceDate: Date(timeIntervalSince1970: 1_700_000_000)
        )

        await viewModel.onAppear()

        #expect(viewModel.state.currentValue?.map(\.id) == ["far", "near"])
    }
}
