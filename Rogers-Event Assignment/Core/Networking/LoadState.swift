import Foundation

/// Unified state machine used by every ViewModel in the app for anything that loads
/// asynchronously. Failures retain the last-known-good `previous` value so the UI can
/// degrade to "stale but visible" instead of going blank.
enum LoadState<Value: Equatable & Sendable>: Equatable, Sendable {
    case idle
    case loading(previous: Value?)
    case loaded(Value)
    case failed(APIError, previous: Value?)

    /// The most recent value we have, regardless of whether the current state succeeded.
    var currentValue: Value? {
        switch self {
        case .idle:
            return nil
        case .loading(let previous):
            return previous
        case .loaded(let value):
            return value
        case .failed(_, let previous):
            return previous
        }
    }

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    var error: APIError? {
        if case .failed(let error, _) = self { return error }
        return nil
    }
}
