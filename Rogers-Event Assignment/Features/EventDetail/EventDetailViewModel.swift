import Combine
import CoreLocation
import Foundation
import MapKit

@MainActor
final class EventDetailViewModel: ObservableObject {
    @Published private(set) var event: Event
    @Published private(set) var distanceText: String?

    private let eventStore: EventStore
    private let locationService: LocationService

    init(event: Event, eventStore: EventStore, locationService: LocationService) {
        self.event = event
        self.eventStore = eventStore
        self.locationService = locationService
    }

    func onAppear() async {
        guard let location = await locationService.currentLocation() else { return }
        distanceText = DistanceFormatter.string(from: location, to: event.venue)
    }

    func toggleBookmark() async {
        guard let updated = await eventStore.setBookmarked(!event.isBookmarked, for: event.id) else { return }
        event = updated
    }

    /// Deep-links to the native Maps app for turn-by-turn navigation. Uses
    /// `MKMapItem.openInMaps`, not a hand-rolled URL scheme, so it behaves correctly
    /// regardless of what map apps the user has installed. `MKPlacemark` +
    /// `MKMapItem(placemark:)` were deprecated in iOS 26 in favor of
    /// `MKMapItem(location:address:)`.
    func openInMaps() {
        guard let venue = event.venue, let latitude = venue.latitude, let longitude = venue.longitude else { return }
        let location = CLLocation(latitude: latitude, longitude: longitude)
        let mapItem = MKMapItem(location: location, address: nil)
        mapItem.name = venue.name
        mapItem.openInMaps()
    }
}
