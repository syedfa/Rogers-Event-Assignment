import Foundation

/// TTL'd cache of raw API response bodies, keyed by request URL. Two tiers: an
/// in-memory dictionary for the common case (same query repeated within a session)
/// and a disk tier (in `Caches/`, OS-purgeable) so a relaunch within the TTL window
/// still avoids a network round trip. Actor-isolated so concurrent reads/writes from
/// multiple in-flight fetches never race.
actor ResponseCache {
    private struct Entry: Codable {
        let data: Data
        let storedAt: Date
    }

    private var memory: [String: Entry] = [:]
    private let ttl: TimeInterval
    private let clock: Clock
    private let directory: URL
    private let fileManager: FileManager

    init(
        ttl: TimeInterval = 600,
        clock: Clock = SystemClock(),
        directory: URL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ResponseCache", isDirectory: true),
        fileManager: FileManager = .default
    ) {
        self.ttl = ttl
        self.clock = clock
        self.directory = directory
        self.fileManager = fileManager
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    /// Returns cached data for `key` only if it hasn't expired. Falls back to the
    /// disk tier (and repopulates memory) when the in-memory entry is missing —
    /// e.g. after a cold launch.
    func data(for key: String) -> Data? {
        if let entry = memory[key] {
            return isFresh(entry) ? entry.data : nil
        }

        guard let entry = readDisk(key) else { return nil }
        memory[key] = entry
        return isFresh(entry) ? entry.data : nil
    }

    func store(_ data: Data, for key: String) {
        let entry = Entry(data: data, storedAt: clock.now())
        memory[key] = entry
        writeDisk(entry, key: key)
    }

    func invalidate(_ key: String) {
        memory[key] = nil
        try? fileManager.removeItem(at: fileURL(for: key))
    }

    private func isFresh(_ entry: Entry) -> Bool {
        clock.now().timeIntervalSince(entry.storedAt) < ttl
    }

    private func fileURL(for key: String) -> URL {
        directory.appendingPathComponent(key.sha256Hex)
    }

    private func readDisk(_ key: String) -> Entry? {
        guard let data = try? Data(contentsOf: fileURL(for: key)) else { return nil }
        return try? JSONDecoder().decode(Entry.self, from: data)
    }

    private func writeDisk(_ entry: Entry, key: String) {
        guard let encoded = try? JSONEncoder().encode(entry) else { return }
        try? encoded.write(to: fileURL(for: key), options: .atomic)
    }
}
