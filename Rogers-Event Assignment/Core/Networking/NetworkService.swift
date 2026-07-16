import Foundation

/// Single choke point for every network call the app makes. Retry/backoff logic
/// lives here exactly once via `RetryPolicy`, rather than being duplicated in each
/// feature that needs data from the network.
protocol NetworkService: Sendable {
    func send<T: Decodable & Sendable>(_ request: URLRequest, decodingTo type: T.Type) async -> Result<T, APIError>
}

final class URLSessionNetworkService: NetworkService, @unchecked Sendable {
    private let session: URLSession
    private let retryPolicy: RetryPolicy
    private let decoder: JSONDecoder

    init(session: URLSession = .shared, retryPolicy: RetryPolicy = .default, decoder: JSONDecoder = JSONDecoder()) {
        self.session = session
        self.retryPolicy = retryPolicy
        self.decoder = decoder
    }

    func send<T: Decodable & Sendable>(_ request: URLRequest, decodingTo type: T.Type) async -> Result<T, APIError> {
        var attempt = 1

        while true {
            let outcome = await performOnce(request, decodingTo: type)

            switch outcome {
            case .success(let value):
                return .success(value)
            case .failure(let error):
                let canRetry = retryPolicy.isRetryable(error) && attempt < retryPolicy.maxAttempts
                guard canRetry else { return .failure(error) }

                let delay = retryPolicy.delay(forAttempt: attempt)
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                attempt += 1
            }
        }
    }

    private func performOnce<T: Decodable>(_ request: URLRequest, decodingTo type: T.Type) async -> Result<T, APIError> {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { return .failure(.network) }

            switch http.statusCode {
            case 200..<300:
                do {
                    return .success(try decoder.decode(T.self, from: data))
                } catch {
                    return .failure(.decoding)
                }
            case 401:
                return .failure(.unauthorized)
            case 500...599:
                return .failure(.server(statusCode: http.statusCode))
            default:
                return .failure(.invalidRequest(statusCode: http.statusCode))
            }
        } catch is CancellationError {
            return .failure(.cancelled)
        } catch {
            if let urlError = error as? URLError, urlError.code == .cancelled {
                return .failure(.cancelled)
            }
            return .failure(.network)
        }
    }
}
