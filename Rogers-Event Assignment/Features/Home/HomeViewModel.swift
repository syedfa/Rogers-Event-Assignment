import Combine
import CoreLocation
import Foundation

/// Owns the Home screen's selected date, selected segment, and the resulting
/// `LoadState<[Event]>`. Explore reads through `EventsRepository` (network +
/// response cache) filtered to the selected date; Bookmarked reads `EventStore`
/// directly, never touches the network, and ignores the selected date entirely.
@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var state: LoadState<[Event]> = .idle
    @Published private(set) var selectedDate: Date
    @Published private(set) var selectedSegment: EventSegment = .explore
    @Published private(set) var locationAuthorizationStatus: CLAuthorizationStatus

    let dateStripDays: [Date]

    private let repository: EventsRepository
    private let eventStore: EventStore
    private let locationService: LocationService
    private let clock: Clock
    private var lastKnownLocation: CLLocation?

    init(
        repository: EventsRepository,
        eventStore: EventStore,
        locationService: LocationService,
        clock: Clock = SystemClock(),
        referenceDate: Date = Date(),
        dateStripDaysBefore: Int = 3,
        dateStripDaysAfter: Int = 3
    ) {
        self.repository = repository
        self.eventStore = eventStore
        self.locationService = locationService
        self.clock = clock

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: referenceDate)
        self.selectedDate = today
        self.locationAuthorizationStatus = locationService.authorizationStatus
        self.dateStripDays = (-dateStripDaysBefore...dateStripDaysAfter).compactMap {
            calendar.date(byAdding: .day, value: $0, to: today)
        }
    }

    func onAppear() async {
        lastKnownLocation = await locationService.currentLocation()
        await load()
    }

    func select(date: Date) async {
        selectedDate = Calendar.current.startOfDay(for: date)
        // Bookmarked is date-independent — it always shows every saved event,
        // regardless of what's selected in the date strip.
        guard selectedSegment == .explore else { return }
        await load()
    }

    func select(segment: EventSegment) async {
        selectedSegment = segment
        await load()
    }

    func toggleBookmark(for event: Event) async {
        await eventStore.setBookmarked(!event.isBookmarked, for: event.id)
        await load()
    }

    func requestLocationPermission() async {
        await locationService.requestWhenInUseAuthorization()
        locationAuthorizationStatus = locationService.authorizationStatus
        lastKnownLocation = await locationService.currentLocation()
        await load()
    }

    /// Distance from the user's real, live location to `event`'s venue — `nil`
    /// whenever a live location isn't available. Deliberately never falls back to
    /// `DefaultLocation.fallback`: that fallback exists only to bias the *query*
    /// toward a populated area, and showing a distance computed from it would be a
    /// number the user never asked for and can't verify.
    func distanceText(for event: Event) -> String? {
        DistanceFormatter.string(from: lastKnownLocation, to: event.venue)
    }

    func load() async {
        // Falls back to a default location when no live device location is
        // available (permission not granted, or — notably in the Simulator — no
        // GPS fix set) so Explore still has something geographically meaningful to
        // query instead of the sparse, largely non-matching global catalog. Never
        // used for displayed distance or proximity sorting — both of those only
        // ever use a real, live location.
        let queryLocation = lastKnownLocation ?? DefaultLocation.fallback

        switch selectedSegment {
        case .explore:
            await repository.fetchEvents(for: selectedDate, near: queryLocation) { [weak self] newState in
                self?.apply(newState)
            }
        case .bookmarked:
            state = .loading(previous: state.currentValue)
            let events = await eventStore.bookmarked()
            state = .loaded(sortedByProximity(events))
        }
    }

    private func apply(_ newState: LoadState<[Event]>) {
        switch newState {
        case .idle:
            state = .idle
        case .loading(let previous):
            state = .loading(previous: previous.map(sortedByProximity))
        case .loaded(let events):
            state = .loaded(sortedByProximity(events))
        case .failed(let error, let previous):
            state = .failed(error, previous: previous.map(sortedByProximity))
        }
    }

    /// Orders events nearest-to-farthest from the user's real, live location.
    /// Leaves the (already date-sorted) order untouched when no live location is
    /// available, or pushes events with no resolvable venue coordinate to the end
    /// rather than dropping them.
    private func sortedByProximity(_ events: [Event]) -> [Event] {
        guard let location = lastKnownLocation else { return events }
        return events.sorted {
            (distanceMeters(from: location, to: $0.venue) ?? .greatestFiniteMagnitude)
                < (distanceMeters(from: location, to: $1.venue) ?? .greatestFiniteMagnitude)
        }
    }

    private func distanceMeters(from location: CLLocation, to venue: Venue?) -> Double? {
        guard let venue, let latitude = venue.latitude, let longitude = venue.longitude else { return nil }
        return location.distance(from: CLLocation(latitude: latitude, longitude: longitude))
    }

    /// Warms `EventStore` with real data for every day in the date strip, not just
    /// the selected one, so switching dates in Explore feels instant.
    ///
    /// Deliberately separate from `onAppear()` / `load()` rather than awaited
    /// inline — `HomeView` fires this from its own `.task`, running concurrently so
    /// up to 6 background network calls never delay the initial screen or the
    /// location permission primer.
    func prefetchDateStripDays() async {
        let location = lastKnownLocation ?? DefaultLocation.fallback
        for day in dateStripDays where !Calendar.current.isDate(day, inSameDayAs: selectedDate) {
            await repository.fetchEvents(for: day, near: location) { _ in }
        }
    }
}
