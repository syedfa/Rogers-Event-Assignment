import Foundation

/// Realistic (trimmed) Ticketmaster Discovery API `/events.json` response bodies,
/// embedded as source rather than bundled resource files — avoids any Xcode
/// resource-copying configuration for what's purely decode-test input.
enum TicketmasterFixtures {
    // The `dates.start.dateTime` baked into `singleFullEvent` and
    // `mixedVenueAndNoVenueEvents`'s "abc123" — tests that expect these fixtures to
    // survive `DefaultEventsRepository`'s within-window date filter must fetch for
    // this date (or one on the same local day), not an arbitrary "now". Force-unwrap
    // below is a hardcoded, always-valid ISO8601 literal.
    // swiftlint:disable:next force_unwrapping
    static let sampleEventStartDate = ISO8601DateFormatter().date(from: "2026-08-01T23:30:00Z")!

    static let singleFullEvent = """
    {
      "_embedded": {
        "events": [
          {
            "id": "abc123",
            "name": "Sample Concert",
            "url": "https://www.ticketmaster.com/event/abc123",
            "classifications": [ { "segment": { "name": "Music" } } ],
            "dates": {
              "start": {
                "localDate": "2026-08-01",
                "localTime": "19:30:00",
                "dateTime": "2026-08-01T23:30:00Z"
              },
              "timezone": "America/Toronto"
            },
            "images": [
              { "url": "https://example.com/small.jpg", "width": 200, "height": 112, "ratio": "16_9" },
              { "url": "https://example.com/large.jpg", "width": 1024, "height": 576, "ratio": "16_9" },
              { "url": "https://example.com/square.jpg", "width": 500, "height": 500, "ratio": "1_1" }
            ],
            "_embedded": {
              "venues": [
                {
                  "name": "Scotiabank Arena",
                  "city": { "name": "Toronto" },
                  "address": { "line1": "40 Bay St" },
                  "location": { "latitude": "43.643333", "longitude": "-79.379167" }
                }
              ]
            }
          }
        ]
      }
    }
    """

    static let eventMissingOptionalFields = """
    {
      "_embedded": {
        "events": [
          {
            "id": "xyz789",
            "name": "TBD Event"
          }
        ]
      }
    }
    """

    static let emptyResponse = "{}"

    /// One event with a real venue, one without (Ticketmaster's digital-content
    /// listings) — used to verify the repository filters out venue-less events.
    static let mixedVenueAndNoVenueEvents = """
    {
      "_embedded": {
        "events": [
          {
            "id": "abc123",
            "name": "Sample Concert",
            "dates": {
              "start": { "dateTime": "2026-08-01T23:30:00Z" }
            },
            "_embedded": {
              "venues": [
                { "name": "Scotiabank Arena", "location": { "latitude": "43.643333", "longitude": "-79.379167" } }
              ]
            }
          },
          {
            "id": "digital456",
            "name": "Digital Redirect Download: Something"
          }
        ]
      }
    }
    """
}
