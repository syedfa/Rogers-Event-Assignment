import CoreLocation
import Foundation

/// Orchestrates network + `ResponseCache` + `EventStore` with a stale-while-revalidate
/// flow. This is the only thing ViewModels talk to for event data — they never touch
/// `NetworkService` or `EventStore` directly for the Upcoming segment.
protocol EventsRepository: Sendable {
    /// Emits a cached result immediately (if any exists and hasn't expired) via
    /// `onUpdate`, then always attempts a network refresh and emits again with the
    /// outcome. `onUpdate` is called once if there's no cache, twice if there is.
    func fetchUpcoming(
        for date: Date,
        near location: CLLocation?,
        onUpdate: @escaping @MainActor @Sendable (LoadState<[Event]>) -> Void
    ) async

    /// Emits whatever's already cached in `EventStore` for events that occurred on
    /// `date` immediately, then queries the network for that same single day
    /// (sorted most-recent-first), upserts the results, and emits the merged local
    /// view — the exact mirror of `fetchUpcoming`, just for a day that's already
    /// happened. The Discovery API does serve already-elapsed events for an
    /// explicit past date range — it's just not the default result set.
    ///
    /// An event counts as "past" once it has actually started, even if that's
    /// today: selecting today shows today's events up to and including whichever
    /// one is happening right now, and excludes only what's later today and hasn't
    /// started yet. Selecting a fully future day always emits an empty result with
    /// no network call, since nothing on it could have started.
    func fetchPast(
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

    func fetchUpcoming(
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

    func fetchPast(
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
        // Nothing on `date` counts as "past" beyond right now — this matters when
        // `date` is today, where events later today haven't started yet.
        let occurredCutoff = min(windowEnd, clock.now())

        let cachedEvents = await pastEvents(windowStart: windowStart, occurredCutoff: occurredCutoff)
        await onUpdate(cachedEvents.isEmpty ? .loading(previous: nil) : .loaded(cachedEvents))

        guard occurredCutoff > windowStart else {
            // `date` is entirely in the future — nothing could have started yet, so
            // there's no point making a network call at all.
            await onUpdate(.loaded([]))
            return
        }

        let request = TicketmasterEndpoint.events(
            apiKey: apiKey,
            latitude: location?.coordinate.latitude,
            longitude: location?.coordinate.longitude,
            startDateTime: windowStart,
            endDateTime: windowEnd,
            sort: .dateDescending
        )

        let result = await network.send(request, decodingTo: TicketmasterEventsResponse.self)

        // The displayed list is always re-derived from EventStore (via
        // `pastEvents(windowStart:occurredCutoff:)`), which filters by each event's
        // real `startDate` client-side — so an unreliable server-side date filter
        // can't leak wrong-day or not-yet-started events into what's shown, unlike
        // if we emitted the network response directly.
        switch result {
        case .success(let response):
            let mapped = Self.mapAndFilter(response.embedded?.events ?? [], within: windowStart..<windowEnd)
            await eventStore.upsert(mapped, fetchedAt: clock.now())
            let merged = await pastEvents(windowStart: windowStart, occurredCutoff: occurredCutoff)
            await onUpdate(.loaded(merged))
        case .failure(let error):
            await onUpdate(.failed(error, previous: cachedEvents.isEmpty ? nil : cachedEvents))
        }
    }

    /// Persisted events that both fall on `windowStart`'s day and have already
    /// started (`startDate < occurredCutoff`). Builds on `EventStore.past(before:)`
    /// rather than a new SwiftData predicate — its date-optional handling is
    /// already exercised and known-reliable (see that method's own comment).
    private func pastEvents(windowStart: Date, occurredCutoff: Date) async -> [Event] {
        await eventStore.past(before: occurredCutoff).filter { event in
            guard let startDate = event.startDate else { return false }
            return startDate >= windowStart
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
    /// without this, "Upcoming" would show the same stale results for every day.
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
