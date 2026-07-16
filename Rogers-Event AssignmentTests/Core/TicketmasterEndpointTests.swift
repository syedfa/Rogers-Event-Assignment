import Foundation
@testable import Rogers_Event_Assignment
import Testing

struct TicketmasterEndpointTests {
    @Test func includesApiKeySortAndPage() {
        let request = TicketmasterEndpoint.events(apiKey: "KEY123", page: 2)
        let items = queryItems(request)
        #expect(items["apikey"] == "KEY123")
        #expect(items["sort"] == "date,asc")
        #expect(items["page"] == "2")
    }

    @Test func includesLatLongAndRadiusWhenLocationProvided() {
        let request = TicketmasterEndpoint.events(apiKey: "KEY", latitude: 43.65, longitude: -79.38, radiusMiles: 10)
        let items = queryItems(request)
        #expect(items["latlong"] == "43.65,-79.38")
        #expect(items["radius"] == "10")
    }

    @Test func omitsLatLongAndRadiusWhenLocationIsNil() {
        let request = TicketmasterEndpoint.events(apiKey: "KEY")
        let items = queryItems(request)
        #expect(items["latlong"] == nil)
        #expect(items["radius"] == nil)
    }

    @Test func includesDateWindowWhenProvided() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = Date(timeIntervalSince1970: 1_700_086_400)
        let request = TicketmasterEndpoint.events(apiKey: "KEY", startDateTime: start, endDateTime: end)
        let items = queryItems(request)
        #expect(items["startDateTime"] != nil)
        #expect(items["endDateTime"] != nil)
        #expect(items["startDateTime"]?.hasSuffix("Z") == true)
    }

    @Test func omitsDateWindowWhenNotProvided() {
        let request = TicketmasterEndpoint.events(apiKey: "KEY")
        let items = queryItems(request)
        #expect(items["startDateTime"] == nil)
        #expect(items["endDateTime"] == nil)
    }

    @Test func urlPointsAtDiscoveryEventsEndpoint() {
        let request = TicketmasterEndpoint.events(apiKey: "KEY")
        #expect(request.url?.host == "app.ticketmaster.com")
        #expect(request.url?.path == "/discovery/v2/events.json")
    }

    private func queryItems(_ request: URLRequest) -> [String: String] {
        guard let url = request.url, let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return [:]
        }
        var dict: [String: String] = [:]
        for item in components.queryItems ?? [] {
            dict[item.name] = item.value
        }
        return dict
    }
}
