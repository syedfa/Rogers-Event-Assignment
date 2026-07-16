import CryptoKit
import Foundation

extension String {
    /// Deterministic filesystem-safe cache key derived from an arbitrary string
    /// (typically a request or image URL). CryptoKit is a first-party Apple
    /// framework, not a third-party dependency.
    var sha256Hex: String {
        let digest = SHA256.hash(data: Data(utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
