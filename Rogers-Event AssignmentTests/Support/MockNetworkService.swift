import Foundation
@testable import Rogers_Event_Assignment

/// Fake `NetworkService` conforming to the exact protocol production code uses —
/// no URL-stubbing hacks. Returns raw `Data` from `handler`, decoded generically
/// just like the real implementation would.
final class MockNetworkService: NetworkService, @unchecked Sendable {
    private let handler: @Sendable (URLRequest) -> Result<Data, APIError>

    init(handler: @escaping @Sendable (URLRequest) -> Result<Data, APIError>) {
        self.handler = handler
    }

    func send<T: Decodable & Sendable>(_ request: URLRequest, decodingTo type: T.Type) async -> Result<T, APIError> {
        switch handler(request) {
        case .success(let data):
            do {
                return .success(try JSONDecoder().decode(T.self, from: data))
            } catch {
                return .failure(.decoding)
            }
        case .failure(let error):
            return .failure(error)
        }
    }
}
