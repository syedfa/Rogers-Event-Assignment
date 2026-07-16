import CoreLocation
import Foundation
@testable import Rogers_Event_Assignment
import Testing

@MainActor
struct EventDetailViewModelTests {
    private func sampleEvent(isBookmarked: Bool = false) -> Event {
        Event(
            id: "e1",
            title: "Show",
            category: "Music",
            startDate: Date(),
            timeZoneIdentifier: nil,
            imageURL: nil,
            infoURL: nil,
            venue: Venue(name: "Venue", address: nil, city: nil, latitude: 43.65, longitude: -79.38),
            isBookmarked: isBookmarked
        )
    }

    @Test func toggleBookmarkFlipsStateAndPersistsAcrossToggles() async {
        let store = SwiftDataEventStore(modelContainer: ModelContainerFactory.make(inMemory: true))
        await store.upsert([sampleEvent()], fetchedAt: Date())

        let viewModel = EventDetailViewModel(event: sampleEvent(), eventStore: store, locationService: FakeLocationService())
        #expect(viewModel.event.isBookmarked == false)

        await viewModel.toggleBookmark()
        #expect(viewModel.event.isBookmarked == true)
        #expect(await store.event(id: "e1")?.isBookmarked == true)

        await viewModel.toggleBookmark()
        #expect(viewModel.event.isBookmarked == false)
        #expect(await store.event(id: "e1")?.isBookmarked == false)
    }

    @Test func computesDistanceWhenLocationIsAvailable() async {
        let store = SwiftDataEventStore(modelContainer: ModelContainerFactory.make(inMemory: true))
        await store.upsert([sampleEvent()], fetchedAt: Date())

        let location = FakeLocationService()
        location.location = CLLocation(latitude: 43.66, longitude: -79.40)

        let viewModel = EventDetailViewModel(event: sampleEvent(), eventStore: store, locationService: location)
        await viewModel.onAppear()

        #expect(viewModel.distanceText != nil)
    }

    @Test func distanceIsNilWhenLocationIsUnavailable() async {
        let store = SwiftDataEventStore(modelContainer: ModelContainerFactory.make(inMemory: true))
        let location = FakeLocationService()
        location.location = nil

        let viewModel = EventDetailViewModel(event: sampleEvent(), eventStore: store, locationService: location)
        await viewModel.onAppear()

        #expect(viewModel.distanceText == nil)
    }
}
