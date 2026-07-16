import Foundation

/// Unified error classification for every network-touching operation in the app.
/// `RetryPolicy` decides which cases are retryable; ViewModels only ever see this type.
enum APIError: Error, Equatable, Sendable {
    /// Connectivity failure (timeout, offline, DNS, etc). Retryable.
    case network
    /// 5xx response. Retryable.
    case server(statusCode: Int)
    /// 401 response — bad or missing API key. Not retryable.
    case unauthorized
    /// Any other 4xx response. Not retryable.
    case invalidRequest(statusCode: Int)
    /// Response body didn't match the expected shape. Not retryable.
    case decoding
    /// The operation was cancelled by the caller. Not retryable.
    case cancelled
}
