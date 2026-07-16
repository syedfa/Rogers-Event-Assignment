import Foundation
@testable import Rogers_Event_Assignment
import Testing

struct EventMappingTests {
    @Test func decodesFullEventWithVenueAndBestImage() throws {
        let data = Data(TicketmasterFixtures.singleFullEvent.utf8)
        let response = try JSONDecoder().decode(TicketmasterEventsResponse.self, from: data)
        let dto = try #require(response.embedded?.events.first)
        let event = dto.toDomain()

        #expect(event.id == "abc123")
        #expect(event.title == "Sample Concert")
        #expect(event.category == "Music")
        #expect(event.venue?.name == "Scotiabank Arena")
        #expect(event.venue?.city == "Toronto")
        #expect(event.venue?.latitude == 43.643333)
        #expect(event.venue?.longitude == -79.379167)
        // Prefers the widest 16:9 image over the square or smaller wide variant.
        #expect(event.imageURL?.absoluteString == "https://example.com/large.jpg")
        #expect(event.startDate != nil)
        #expect(event.isBookmarked == false)
    }

    @Test func decodesEventWithMissingOptionalFieldsWithoutCrashing() throws {
        let data = Data(TicketmasterFixtures.eventMissingOptionalFields.utf8)
        let response = try JSONDecoder().decode(TicketmasterEventsResponse.self, from: data)
        let dto = try #require(response.embedded?.events.first)
        let event = dto.toDomain()

        #expect(event.id == "xyz789")
        #expect(event.title == "TBD Event")
        #expect(event.category == nil)
        #expect(event.venue == nil)
        #expect(event.imageURL == nil)
        #expect(event.startDate == nil)
    }

    @Test func decodesEmptyResponseAsNoEvents() throws {
        let data = Data(TicketmasterFixtures.emptyResponse.utf8)
        let response = try JSONDecoder().decode(TicketmasterEventsResponse.self, from: data)
        #expect(response.embedded == nil)
    }
}
