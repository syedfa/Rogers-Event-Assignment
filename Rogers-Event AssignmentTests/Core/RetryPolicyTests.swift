@testable import Rogers_Event_Assignment
import Testing

struct RetryPolicyTests {
    @Test func networkAndServerErrorsAreRetryable() {
        let policy = RetryPolicy.default
        #expect(policy.isRetryable(.network))
        #expect(policy.isRetryable(.server(statusCode: 503)))
    }

    @Test func terminalErrorsAreNotRetryable() {
        let policy = RetryPolicy.default
        #expect(!policy.isRetryable(.unauthorized))
        #expect(!policy.isRetryable(.invalidRequest(statusCode: 400)))
        #expect(!policy.isRetryable(.decoding))
        #expect(!policy.isRetryable(.cancelled))
    }

    @Test func delayGrowsExponentiallyAndCapsAtMaxDelay() {
        let policy = RetryPolicy(maxAttempts: 5, baseDelay: 1, maxDelay: 8)
        let zeroJitter = { 0.0 }
        #expect(policy.delay(forAttempt: 1, jitter: zeroJitter) == 1)
        #expect(policy.delay(forAttempt: 2, jitter: zeroJitter) == 2)
        #expect(policy.delay(forAttempt: 3, jitter: zeroJitter) == 4)
        #expect(policy.delay(forAttempt: 4, jitter: zeroJitter) == 8) // would be 8, exactly at cap
        #expect(policy.delay(forAttempt: 5, jitter: zeroJitter) == 8) // would be 16, capped to 8
    }

    @Test func jitterAddsUpToTenPercentOfCappedDelay() {
        let policy = RetryPolicy(maxAttempts: 5, baseDelay: 1, maxDelay: 8)
        let noJitter = policy.delay(forAttempt: 1, jitter: { 0.0 })
        let maxJitter = policy.delay(forAttempt: 1, jitter: { 1.0 })
        #expect(noJitter == 1.0)
        #expect(maxJitter == 1.1)
    }
}
