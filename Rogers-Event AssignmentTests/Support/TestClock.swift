import Foundation
@testable import Rogers_Event_Assignment

/// Mutable, deterministic `Clock` for TTL-expiry and timing tests — no real
/// `sleep`, no flakiness.
final class TestClock: Clock, @unchecked Sendable {
    var date: Date

    init(date: Date = Date(timeIntervalSince1970: 1_700_000_000)) {
        self.date = date
    }

    func now() -> Date { date }

    func advance(by seconds: TimeInterval) {
        date = date.addingTimeInterval(seconds)
    }
}
