import Foundation
@testable import Rogers_Event_Assignment
import Testing

struct ResponseCacheTests {
    private func tempDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    @Test func storesAndReturnsFreshData() async {
        let cache = ResponseCache(ttl: 600, clock: TestClock(), directory: tempDirectory())
        let data = Data("hello".utf8)
        await cache.store(data, for: "key1")
        #expect(await cache.data(for: "key1") == data)
    }

    @Test func returnsNilForMissingKey() async {
        let cache = ResponseCache(ttl: 600, clock: TestClock(), directory: tempDirectory())
        #expect(await cache.data(for: "missing") == nil)
    }

    @Test func expiresAfterTTL() async {
        let clock = TestClock()
        let cache = ResponseCache(ttl: 60, clock: clock, directory: tempDirectory())
        await cache.store(Data("hello".utf8), for: "key1")
        clock.advance(by: 61)
        #expect(await cache.data(for: "key1") == nil)
    }

    @Test func staysFreshRightBeforeTTLExpires() async {
        let clock = TestClock()
        let cache = ResponseCache(ttl: 60, clock: clock, directory: tempDirectory())
        await cache.store(Data("hello".utf8), for: "key1")
        clock.advance(by: 59)
        #expect(await cache.data(for: "key1") != nil)
    }

    @Test func fallsBackToDiskAcrossInstances() async {
        let clock = TestClock()
        let directory = tempDirectory()
        let data = Data("persisted".utf8)

        let first = ResponseCache(ttl: 600, clock: clock, directory: directory)
        await first.store(data, for: "key1")

        // New instance, same directory — simulates a cold relaunch where the
        // in-memory tier is empty but the disk tier survived.
        let second = ResponseCache(ttl: 600, clock: clock, directory: directory)
        #expect(await second.data(for: "key1") == data)
    }

    @Test func invalidateRemovesEntryFromMemoryAndDisk() async {
        let clock = TestClock()
        let directory = tempDirectory()
        let cache = ResponseCache(ttl: 600, clock: clock, directory: directory)
        await cache.store(Data("hello".utf8), for: "key1")

        await cache.invalidate("key1")

        #expect(await cache.data(for: "key1") == nil)
        let reloaded = ResponseCache(ttl: 600, clock: clock, directory: directory)
        #expect(await reloaded.data(for: "key1") == nil)
    }
}
