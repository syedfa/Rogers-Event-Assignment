import Foundation

/// Builds `URLRequest`s for the Ticketmaster Discovery API. Pure function of its
/// inputs — no I/O, no state — so it's testable without touching the network.
enum TicketmasterEndpoint {
    static let baseURL = URL(string: "https://app.ticketmaster.com/discovery/v2/events.json")!

    enum SortOrder: String {
        case dateAscending = "date,asc"
        case dateDescending = "date,desc"
    }

    static func events(
        apiKey: String,
        latitude: Double? = nil,
        longitude: Double? = nil,
        radiusMiles: Int = 25,
        startDateTime: Date? = nil,
        endDateTime: Date? = nil,
        page: Int = 0,
        sort: SortOrder = .dateAscending
    ) -> URLRequest {
        // baseURL is a well-formed compile-time constant; this can never fail.
        // swiftlint:disable:next force_unwrapping
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!

        var items = [
            URLQueryItem(name: "apikey", value: apiKey),
            URLQueryItem(name: "sort", value: sort.rawValue),
            URLQueryItem(name: "page", value: String(page))
        ]

        if let latitude, let longitude {
            items.append(URLQueryItem(name: "latlong", value: "\(latitude),\(longitude)"))
            items.append(URLQueryItem(name: "radius", value: String(radiusMiles)))
        }

        if let startDateTime {
            items.append(URLQueryItem(name: "startDateTime", value: iso(startDateTime)))
        }

        if let endDateTime {
            items.append(URLQueryItem(name: "endDateTime", value: iso(endDateTime)))
        }

        components.queryItems = items
        // components was built from a valid base URL plus URLQueryItems, which
        // URLComponents always percent-encodes safely; this can never fail.
        // swiftlint:disable:next force_unwrapping
        return URLRequest(url: components.url!)
    }

    /// Ticketmaster expects `yyyy-MM-ddTHH:mm:ssZ` (no fractional seconds, no colon
    /// in the timezone offset — literal "Z").
    private static func iso(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }
}
