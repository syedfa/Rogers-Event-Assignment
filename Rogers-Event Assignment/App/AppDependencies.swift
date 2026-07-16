import Foundation
import SwiftData

/// The single composition root. Every concrete type is constructed exactly once,
/// here, and handed to collaborators as a protocol. Nothing outside this file
/// constructs `URLSessionNetworkService`, `CoreLocationService`, etc. — that's what
/// makes every layer independently testable with fakes.
@MainActor
final class AppDependencies {
    let modelContainer: ModelContainer
    let eventStore: EventStore
    let networkService: NetworkService
    let responseCache: ResponseCache
    let imageCache: ImageCache
    let locationService: LocationService
    let eventsRepository: EventsRepository
    let backgroundRefreshScheduler: BackgroundRefreshScheduler
    let secretsProvider: SecretsProviding

    init(inMemory: Bool = false, secretsProvider: SecretsProviding = BundledSecretsProvider()) {
        let container = ModelContainerFactory.make(inMemory: inMemory)
        self.modelContainer = container
        self.eventStore = SwiftDataEventStore(modelContainer: container)
        self.networkService = URLSessionNetworkService()
        self.responseCache = ResponseCache()
        self.imageCache = ImageCache()
        self.locationService = CoreLocationService()
        self.secretsProvider = secretsProvider

        let eventStore = self.eventStore
        let networkService = self.networkService
        let responseCache = self.responseCache

        self.eventsRepository = DefaultEventsRepository(
            network: networkService,
            responseCache: responseCache,
            eventStore: eventStore,
            apiKeyProvider: { [secretsProvider] in secretsProvider.ticketmasterAPIKey }
        )
        self.backgroundRefreshScheduler = BackgroundRefreshScheduler(
            repository: eventsRepository,
            eventStore: eventStore,
            locationService: locationService
        )
    }

    func makeHomeViewModel() -> HomeViewModel {
        HomeViewModel(repository: eventsRepository, eventStore: eventStore, locationService: locationService)
    }

    func makeEventDetailViewModel(event: Event) -> EventDetailViewModel {
        EventDetailViewModel(event: event, eventStore: eventStore, locationService: locationService)
    }
}
