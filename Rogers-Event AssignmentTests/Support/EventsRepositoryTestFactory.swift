import Foundation
@testable import Rogers_Event_Assignment

/// Shared factory for `EventsRepositoryTests`, which exercises `DefaultEventsRepository`
/// against an in-memory `EventStore` and `ResponseCache`.
func makeEventsRepository(
    network: MockNetworkService,
    clock: TestClock,
    apiKey: String? = "KEY"
) -> (repository: DefaultEventsRepository, store: EventStore) {
    let store = SwiftDataEventStore(modelContainer: ModelContainerFactory.make(inMemory: true))
    let cache = ResponseCache(
        ttl: 600,
        clock: clock,
        directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    )
    let repository = DefaultEventsRepository(
        network: network,
        responseCache: cache,
        eventStore: store,
        clock: clock,
        apiKeyProvider: { apiKey }
    )
    return (repository, store)
}
