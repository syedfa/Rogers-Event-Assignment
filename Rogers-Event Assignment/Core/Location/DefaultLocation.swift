import CoreLocation

/// Biases the Discovery API query toward a real, populated geographic area when a
/// live device location isn't available — permission not yet granted, denied, or
/// (notably in the iOS Simulator, which has no GPS fix unless one is manually
/// simulated) simply unresolvable even when authorized. Without *some* geographic
/// filter, Ticketmaster's global catalog is dominated by evergreen/digital
/// listings that don't actually fall within any requested day's window — "Upcoming"
/// would otherwise show nothing for virtually every date, confirmed via direct API
/// testing (0 of 11 globally-returned "venue" events fell inside any near-term
/// single-day window).
///
/// This never affects the distance shown on the event detail screen — that only
/// ever uses a real, live device location and stays absent rather than showing a
/// misleading number computed from this fallback.
enum DefaultLocation {
    /// Toronto, ON — arbitrary but reasonable choice; a production app would
    /// derive this from the user's locale/timezone or IP geolocation instead of
    /// hardcoding a single city.
    static let fallback = CLLocation(latitude: 43.6532, longitude: -79.3832)
}
