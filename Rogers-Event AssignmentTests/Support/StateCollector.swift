/// Collects values recorded from a `@MainActor @Sendable` update closure without
/// tripping concurrency-safety diagnostics on a captured local `var`.
final class StateCollector<Value>: @unchecked Sendable {
    private(set) var values: [Value] = []

    func record(_ value: Value) {
        values.append(value)
    }
}

/// Thread-confined call counter for mock handlers that need to vary their
/// response on the Nth invocation (e.g. "succeed once, then fail").
final class Counter: @unchecked Sendable {
    private(set) var value = 0

    @discardableResult
    func increment() -> Int {
        value += 1
        return value
    }
}
