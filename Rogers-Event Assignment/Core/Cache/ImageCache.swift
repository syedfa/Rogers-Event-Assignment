import Foundation

/// TTL'd cache of downloaded event image bytes. Two tiers: `NSCache` in memory
/// (automatically evicted by the system under memory pressure — "smart resource
/// usage" for free) and a disk tier in `Caches/` for persistence across launches.
/// Event artwork essentially never changes for a given event id, so the default TTL
/// is much longer than `ResponseCache`'s. Fully native — no third-party libraries.
actor ImageCache {
    private struct DiskEntry: Codable {
        let data: Data
        let storedAt: Date
    }

    /// `NSCache` values must be classes; wrapping the data with its `storedAt` lets
    /// the memory tier honor the TTL too (it otherwise never expires on its own).
    private final class MemoryEntry {
        let data: Data
        let storedAt: Date
        init(data: Data, storedAt: Date) {
            self.data = data
            self.storedAt = storedAt
        }
    }

    private let memory = NSCache<NSString, MemoryEntry>()
    private let ttl: TimeInterval
    private let clock: Clock
    private let directory: URL
    private let fileManager: FileManager

    init(
        ttl: TimeInterval = 7 * 24 * 3600,
        clock: Clock = SystemClock(),
        directory: URL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ImageCache", isDirectory: true),
        fileManager: FileManager = .default
    ) {
        self.ttl = ttl
        self.clock = clock
        self.directory = directory
        self.fileManager = fileManager
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func image(for url: URL) -> Data? {
        let key = url.absoluteString
        if let cached = memory.object(forKey: key as NSString) {
            guard isFresh(storedAt: cached.storedAt) else {
                memory.removeObject(forKey: key as NSString)
                return nil
            }
            return cached.data
        }

        guard let entry = readDisk(key), isFresh(entry) else { return nil }
        memory.setObject(MemoryEntry(data: entry.data, storedAt: entry.storedAt), forKey: key as NSString)
        return entry.data
    }

    func store(_ data: Data, for url: URL) {
        let key = url.absoluteString
        let now = clock.now()
        memory.setObject(MemoryEntry(data: data, storedAt: now), forKey: key as NSString)
        writeDisk(DiskEntry(data: data, storedAt: now), key: key)
    }

    /// Sweeps the disk tier and removes any entry past its TTL. Intended to be
    /// called opportunistically (e.g. during background refresh) to bound disk usage.
    func evictExpired() {
        guard let files = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return }
        for file in files {
            guard let data = try? Data(contentsOf: file),
                  let entry = try? JSONDecoder().decode(DiskEntry.self, from: data) else { continue }
            if !isFresh(entry) {
                try? fileManager.removeItem(at: file)
            }
        }
    }

    private func isFresh(_ entry: DiskEntry) -> Bool {
        isFresh(storedAt: entry.storedAt)
    }

    private func isFresh(storedAt: Date) -> Bool {
        clock.now().timeIntervalSince(storedAt) < ttl
    }

    private func fileURL(for key: String) -> URL {
        directory.appendingPathComponent(key.sha256Hex)
    }

    private func readDisk(_ key: String) -> DiskEntry? {
        guard let data = try? Data(contentsOf: fileURL(for: key)) else { return nil }
        return try? JSONDecoder().decode(DiskEntry.self, from: data)
    }

    private func writeDisk(_ entry: DiskEntry, key: String) {
        guard let encoded = try? JSONEncoder().encode(entry) else { return }
        try? encoded.write(to: fileURL(for: key), options: .atomic)
    }
}
