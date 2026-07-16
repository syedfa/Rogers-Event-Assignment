import Foundation
@testable import Rogers_Event_Assignment
import Testing

struct ImageCacheTests {
    private func tempDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    @Test func storesAndReturnsFreshImageData() async {
        let cache = ImageCache(ttl: 7 * 24 * 3600, clock: TestClock(), directory: tempDirectory())
        let url = URL(string: "https://example.com/a.jpg")!
        let data = Data([0xFF, 0xD8, 0xFF])
        await cache.store(data, for: url)
        #expect(await cache.image(for: url) == data)
    }

    @Test func expiresAfterTTL() async {
        let clock = TestClock()
        let cache = ImageCache(ttl: 3600, clock: clock, directory: tempDirectory())
        let url = URL(string: "https://example.com/a.jpg")!
        await cache.store(Data([0x01]), for: url)
        clock.advance(by: 3601)
        #expect(await cache.image(for: url) == nil)
    }

    @Test func fallsBackToDiskAcrossInstances() async {
        let clock = TestClock()
        let directory = tempDirectory()
        let url = URL(string: "https://example.com/a.jpg")!
        let data = Data([0x02])

        let first = ImageCache(clock: clock, directory: directory)
        await first.store(data, for: url)

        let second = ImageCache(clock: clock, directory: directory)
        #expect(await second.image(for: url) == data)
    }

    @Test func evictExpiredRemovesOnlyStaleDiskEntries() async {
        let clock = TestClock()
        let directory = tempDirectory()
        let staleURL = URL(string: "https://example.com/stale.jpg")!
        let freshURL = URL(string: "https://example.com/fresh.jpg")!

        let cache = ImageCache(ttl: 3600, clock: clock, directory: directory)
        await cache.store(Data([0x01]), for: staleURL)
        clock.advance(by: 7200)
        await cache.store(Data([0x02]), for: freshURL)
        await cache.evictExpired()

        // Fresh instance forces a disk read since the memory tier isn't shared.
        let reloaded = ImageCache(ttl: 3600, clock: clock, directory: directory)
        #expect(await reloaded.image(for: staleURL) == nil)
        #expect(await reloaded.image(for: freshURL) != nil)
    }
}
