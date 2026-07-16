import Foundation

protocol SecretsProviding: Sendable {
    /// `nil` if no real key has been configured yet (file missing the copy step,
    /// or still holding the placeholder from Secrets.swift.example).
    var ticketmasterAPIKey: String? { get }
}

/// Reads the compile-time key from `Secrets.swift` (gitignored — see
/// Secrets.swift.example and the README for setup) and treats the placeholder
/// value as "not configured" rather than sending it to the network as a literal
/// string that would just 401.
struct BundledSecretsProvider: SecretsProviding {
    private static let placeholder = "YOUR_TICKETMASTER_API_KEY"

    var ticketmasterAPIKey: String? {
        let key = Secrets.ticketmasterAPIKey
        return (key == Self.placeholder || key.isEmpty) ? nil : key
    }
}
