import BackgroundTasks
import CoreLocation
import Foundation
import os

/// Low-frequency background refresh: re-fetches nearby upcoming events and prunes
/// stale (non-bookmarked, per `EventStore.prune`) cached events. Registered once at
/// launch; reschedules itself each time it runs.
final class BackgroundRefreshScheduler: @unchecked Sendable {
    static let taskIdentifier = "ca.cybermedia.Rogers-Event-Assignment.refresh"

    /// How far out the OS is asked to run the next refresh. iOS treats this as a
    /// minimum, not a guarantee — actual timing depends on system heuristics
    /// (usage patterns, battery, etc). Intentionally infrequent per the assignment's
    /// "low frequency" requirement.
    private static let minimumInterval: TimeInterval = 4 * 3600
    private static let pruneWindow: TimeInterval = 30 * 24 * 3600

    private let repository: EventsRepository
    private let eventStore: EventStore
    private let locationService: LocationService
    private let clock: Clock
    private let logger = Logger(subsystem: "ca.cybermedia.Rogers-Event-Assignment", category: "BackgroundRefresh")

    init(repository: EventsRepository, eventStore: EventStore, locationService: LocationService, clock: Clock = SystemClock()) {
        self.repository = repository
        self.eventStore = eventStore
        self.locationService = locationService
        self.clock = clock
    }

    func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.taskIdentifier, using: nil) { [weak self] task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            self?.handle(refreshTask)
        }
    }

    func scheduleNextRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: Self.minimumInterval)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            logger.error("Failed to schedule background refresh: \(error.localizedDescription)")
        }
    }

    private func handle(_ task: BGAppRefreshTask) {
        scheduleNextRefresh()

        let work = Task {
            let location = await locationService.currentLocation() ?? DefaultLocation.fallback
            await repository.refreshUpcomingNearby(near: location)
            await eventStore.prune(olderThan: clock.now().addingTimeInterval(-Self.pruneWindow))
            task.setTaskCompleted(success: true)
        }

        task.expirationHandler = {
            work.cancel()
        }
    }
}
