import CoreLocation
import Foundation

/// Orchestrates network + `ResponseCache` + `EventStore` with a stale-while-revalidate
/// flow. This is the only thing ViewModels talk to for event data — they never touch
/// `NetworkService` or `EventStore` directly for the Explore segment.
protocol EventsRepository: Sendable {
    /// Emits a cached result immediately (if any exists and hasn't expired) via
    /// `onUpdate`, then always attempts a network refresh and emits again with the
    /// outcome. `onUpdate` is called once if there's no cache, twice if there is.
    /// Covers the whole of `date` — events later that day that haven't started yet
    /// are included just like ones already underway or finished.
    func fetchEvents(
        for date: Date,
        near location: CLLocation?,
        onUpdate: @escaping @MainActor @Sendable (LoadState<[Event]>) -> Void
    ) async

    /// Network-only refresh used by background refresh; bypasses the response cache
    /// entirely and swallows failures (nothing to surface to a user in the background).
    func refreshUpcomingNearby(near location: CLLocation?) async
}

final class DefaultEventsRepository: EventsRepository, @unchecked Sendable {
    private let network: NetworkService
    private let responseCache: ResponseCache
    private let eventStore: EventStore
    private let apiKeyProvider: @Sendable () -> String?
    private let clock: Clock

    init(
        network: NetworkService,
        responseCache: ResponseCache,
        eventStore: EventStore,
        clock: Clock = SystemClock(),
        apiKeyProvider: @escaping @Sendable () -> String?
    ) {
        self.network = network
        self.responseCache = responseCache
        self.eventStore = eventStore
        self.clock = clock
        self.apiKeyProvider = apiKeyProvider
    }

    func fetchEvents(
        for date: Date,
        near location: CLLocation?,
        onUpdate: @escaping @MainActor @Sendable (LoadState<[Event]>) -> Void
    ) async {
        guard let apiKey = apiKeyProvider() else {
            await onUpdate(.failed(.unauthorized, previous: nil))
            return
        }

        let calendar = Calendar.current
        let windowStart = calendar.startOfDay(for: date)
        let windowEnd = calendar.date(byAdding: .day, value: 1, to: windowStart) ?? date
        let request = TicketmasterEndpoint.events(
            apiKey: apiKey,
            latitude: location?.coordinate.latitude,
            longitude: location?.coordinate.longitude,
            startDateTime: windowStart,
            endDateTime: windowEnd
        )
        let cacheKey = request.url?.absoluteString ?? ""

        var cachedEvents: [Event]?
        if let cachedData = await responseCache.data(for: cacheKey),
           let response = try? JSONDecoder().decode(TicketmasterEventsResponse.self, from: cachedData) {
            let mapped = Self.mapAndFilter(response.embedded?.events ?? [], within: windowStart..<windowEnd)
            let merged = await eventStore.upsert(mapped, fetchedAt: clock.now())
            cachedEvents = merged
            await onUpdate(.loaded(merged))
        } else {
            await onUpdate(.loading(previous: nil))
        }

        let result = await network.send(request, decodingTo: TicketmasterEventsResponse.self)

        switch result {
        case .success(let response):
            guard let encoded = try? JSONEncoder().encode(response) else {
                await onUpdate(.failed(.decoding, previous: cachedEvents))
                return
            }
            await responseCache.store(encoded, for: cacheKey)
            let mapped = Self.mapAndFilter(response.embedded?.events ?? [], within: windowStart..<windowEnd)
            let merged = await eventStore.upsert(mapped, fetchedAt: clock.now())
            await onUpdate(.loaded(merged))
        case .failure(let error):
            await onUpdate(.failed(error, previous: cachedEvents))
        }
    }

    func refreshUpcomingNearby(near location: CLLocation?) async {
        guard let apiKey = apiKeyProvider() else { return }

        let calendar = Calendar.current
        let windowStart = calendar.startOfDay(for: clock.now())
        let windowEnd = calendar.date(byAdding: .day, value: 1, to: windowStart) ?? clock.now()
        let request = TicketmasterEndpoint.events(
            apiKey: apiKey,
            latitude: location?.coordinate.latitude,
            longitude: location?.coordinate.longitude,
            startDateTime: windowStart,
            endDateTime: windowEnd
        )

        let result = await network.send(request, decodingTo: TicketmasterEventsResponse.self)
        guard case .success(let response) = result else { return }
        let mapped = Self.mapAndFilter(response.embedded?.events ?? [], within: windowStart..<windowEnd)
        await eventStore.upsert(mapped, fetchedAt: clock.now())
    }

    /// Events without a venue (Ticketmaster's digital-content/reissue listings,
    /// which all share one generic stock placeholder image) aren't useful in a
    /// *local* events app — no venue means no distance and no map deep link either.
    ///
    /// `window`, when provided, additionally drops events whose real `startDate`
    /// falls outside the requested range. Ticketmaster's `startDateTime`/
    /// `endDateTime` query params aren't reliably honored for some catalog entries
    /// (confirmed: a request for 2026-07-15 returned an event dated 2024-05-25) —
    /// without this, "Explore" would show the same stale results for every day.
    private static func mapAndFilter(_ dtos: [TicketmasterEventDTO], within window: Range<Date>? = nil) -> [Event] {
        dtos
            .map { $0.toDomain() }
            .filter { $0.venue != nil }
            .filter { event in
                guard let window else { return true }
                guard let startDate = event.startDate else { return false }
                return window.contains(startDate)
            }
    }
}
