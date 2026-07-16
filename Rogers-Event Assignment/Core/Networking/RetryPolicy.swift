import Foundation

/// Exponential backoff with jitter, plus error classification, shared by every
/// network call in the app (interactive fetches and background refresh alike) so
/// retry behavior is written exactly once.
struct RetryPolicy: Sendable {
    let maxAttempts: Int
    let baseDelay: TimeInterval
    let maxDelay: TimeInterval

    static let `default` = RetryPolicy(maxAttempts: 3, baseDelay: 0.5, maxDelay: 8)

    /// Whether an error is worth retrying at all. Connectivity and server-side (5xx)
    /// failures are transient; everything else (auth, malformed request, decoding,
    /// cancellation) will fail identically on retry.
    func isRetryable(_ error: APIError) -> Bool {
        switch error {
        case .network, .server:
            return true
        case .unauthorized, .invalidRequest, .decoding, .cancelled:
            return false
        }
    }

    /// Delay before `attempt` (1-based) is retried: exponential growth from `baseDelay`,
    /// capped at `maxDelay`, plus up to 10% jitter to avoid thundering-herd retries.
    /// `jitter` is injectable so tests can pin it to a deterministic value.
    func delay(forAttempt attempt: Int, jitter: () -> Double = { Double.random(in: 0...1) }) -> TimeInterval {
        precondition(attempt >= 1, "attempt is 1-based")
        let exponential = baseDelay * pow(2, Double(attempt - 1))
        let capped = min(exponential, maxDelay)
        return capped + jitter() * capped * 0.1
    }
}
