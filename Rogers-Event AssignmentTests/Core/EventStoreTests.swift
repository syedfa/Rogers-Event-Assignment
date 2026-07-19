import Foundation
@testable import Rogers_Event_Assignment
import Testing

struct EventStoreTests {
    private func makeStore() -> SwiftDataEventStore {
        SwiftDataEventStore(modelContainer: ModelContainerFactory.make(inMemory: true))
    }

    private func sampleEvent(id: String = "e1", startDate: Date = Date()) -> Event {
        Event(
            id: id,
            title: "Test Event",
            category: "Music",
            startDate: startDate,
            timeZoneIdentifier: nil,
            imageURL: nil,
            infoURL: nil,
            venue: nil,
            isBookmarked: false
        )
    }

    @Test func upsertInsertsNewEvent() async {
        let store = makeStore()
        let merged = await store.upsert([sampleEvent()], fetchedAt: Date())
        #expect(merged.count == 1)
        #expect(await store.event(id: "e1")?.title == "Test Event")
    }

    @Test func upsertPreservesBookmarkOnExistingEvent() async {
        let store = makeStore()
        await store.upsert([sampleEvent()], fetchedAt: Date())
        await store.setBookmarked(true, for: "e1")

        let merged = await store.upsert([sampleEvent()], fetchedAt: Date())

        #expect(merged.first?.isBookmarked == true)
        #expect(await store.event(id: "e1")?.isBookmarked == true)
    }

    @Test func bookmarkRoundTripPersists() async {
        let store = makeStore()
        await store.upsert([sampleEvent()], fetchedAt: Date())

        let bookmarked = await store.setBookmarked(true, for: "e1")
        #expect(bookmarked?.isBookmarked == true)
        #expect(await store.event(id: "e1")?.isBookmarked == true)

        let unbookmarked = await store.setBookmarked(false, for: "e1")
        #expect(unbookmarked?.isBookmarked == false)
        #expect(await store.event(id: "e1")?.isBookmarked == false)
    }

    @Test func setBookmarkedOnUnknownEventReturnsNil() async {
        let store = makeStore()
        #expect(await store.setBookmarked(true, for: "does-not-exist") == nil)
    }

    @Test func bookmarkedReturnsOnlyBookmarkedEvents() async {
        let store = makeStore()
        await store.upsert([sampleEvent(id: "a"), sampleEvent(id: "b")], fetchedAt: Date())
        await store.setBookmarked(true, for: "b")

        let results = await store.bookmarked()
        #expect(results.map(\.id) == ["b"])
    }

    @Test func pruneDeletesOnlyStaleNonBookmarkedEvents() async {
        let store = makeStore()
        let now = Date()
        let old = now.addingTimeInterval(-40 * 24 * 3600)
        let recent = now.addingTimeInterval(-1 * 24 * 3600)

        await store.upsert([sampleEvent(id: "stale")], fetchedAt: old)
        await store.upsert([sampleEvent(id: "recent")], fetchedAt: recent)

        await store.prune(olderThan: now.addingTimeInterval(-30 * 24 * 3600))

        #expect(await store.event(id: "stale") == nil)
        #expect(await store.event(id: "recent") != nil)
    }

    /// The core invariant from the spec: a bookmarked event must never be purged,
    /// no matter how old its last fetch was.
    @Test func pruneNeverDeletesBookmarkedEventsRegardlessOfAge() async {
        let store = makeStore()
        let now = Date()
        let veryOld = now.addingTimeInterval(-365 * 24 * 3600)

        await store.upsert([sampleEvent(id: "old-bookmarked")], fetchedAt: veryOld)
        await store.setBookmarked(true, for: "old-bookmarked")

        await store.prune(olderThan: now.addingTimeInterval(-30 * 24 * 3600))

        let survivor = await store.event(id: "old-bookmarked")
        #expect(survivor != nil)
        #expect(survivor?.isBookmarked == true)
    }

    @Test func eventBecomesPrunableAgainAfterUnbookmarking() async {
        let store = makeStore()
        let now = Date()
        let old = now.addingTimeInterval(-40 * 24 * 3600)

        await store.upsert([sampleEvent(id: "toggle")], fetchedAt: old)
        await store.setBookmarked(true, for: "toggle")
        await store.setBookmarked(false, for: "toggle")

        await store.prune(olderThan: now.addingTimeInterval(-30 * 24 * 3600))

        #expect(await store.event(id: "toggle") == nil)
    }
}
