# Engineering Standards

## Conventions

- **MVVM**: Views are declarative and hold no business logic beyond
  formatting/layout. Every screen has exactly one `@MainActor`
  `ObservableObject` ViewModel that owns a `LoadState<Value>` and exposes
  intents as methods (`select(date:)`, `select(segment:)`,
  `toggleBookmark()`) — never raw published mutable state that a view
  mutates directly.
- **Dependency injection**: everything a type needs is passed into its
  initializer as a protocol. `AppDependencies` is the single composition
  root; nothing else constructs a concrete `URLSessionNetworkService`,
  `CoreLocationService`, etc. This is what makes fakes trivial in tests and
  keeps ViewModels ignorant of *how* data is fetched or stored.
- **Value types over reference types** for domain models (`Event`, `Venue`)
  — they're `Sendable`, `Equatable`, safe to pass across actor boundaries,
  and cheap to compare in tests. SwiftData `@Model` classes (`PersistedEvent`)
  are confined to the `Persistence` layer; the rest of the app only ever
  sees the mapped domain `Event`.
- **One responsibility per type.** `TicketmasterEndpoint` only builds
  requests. `RetryPolicy` only decides retry/backoff. `EventStore` only
  talks to SwiftData. `EventsRepository` is the only type that composes
  network + cache + store — that composition logic lives in exactly one
  place instead of being duplicated per-feature.

## Error handling policy

- All recoverable failures are represented as typed `AppError` /
  `APIError` values, never as thrown `NSError` bags surfaced directly to
  the UI.
- Every network-touching operation flows through `NetworkService`, so retry
  classification (timeouts/5xx = retryable; 4xx/decoding errors = terminal)
  is written **once** in `RetryPolicy` and reused by both the interactive
  fetch path and the background refresh path — the spec's "unified state
  machine... so we don't have to repeat ourselves" requirement.
- ViewModels never let a failure blank out data the user already has:
  `LoadState.failed` carries the `previous` value so failed refreshes
  degrade to "stale but visible" instead of an empty error screen.
- Errors are logged via `os.Logger` (categorized by subsystem), never
  `print`.

## Concurrency rules

- Swift Concurrency (`async`/`await`) throughout; no completion-handler
  APIs in new code.
- Shared mutable state (`ResponseCache`, `ImageCache`) is isolated behind
  `actor`; SwiftData access goes through `EventStore`, which is confined to
  a single context to avoid cross-thread `ModelContext` use.
- ViewModels are `@MainActor`; they `await` calls into actors/services and
  never block the main thread on I/O.
- No detached tasks with unbounded lifetime — background work (background
  refresh, cache eviction) is scoped to `BGAppRefreshTask`'s own expiration
  handling.

## Testing strategy

- **Tests are written before implementation** (see plan) using Swift
  Testing (`@Test`, `#expect`) to match the project's existing test target.
- Pure logic (`RetryPolicy`, `LoadState`, `TicketmasterEndpoint`, JSON
  mapping, distance formatting) is tested with no doubles at all — it's
  just functions of inputs to outputs.
- Actor-based caches are tested with an injected `Clock` abstraction rather
  than real `sleep`, so TTL expiry tests are deterministic and fast.
- SwiftData-backed tests (`EventStoreTests`, ViewModel tests) use an
  in-memory `ModelContainer` (`isStoredInMemoryOnly: true`) — real
  SwiftData behavior, zero disk I/O, fully isolated per test.
- Network-dependent tests use a `MockNetworkService` conforming to the same
  `NetworkService` protocol production code uses — no URL-stubbing hacks.
- UI (SwiftUI `View` bodies) is intentionally **not** unit tested; view
  logic is kept thin enough that ViewModel tests cover the behavior that
  matters. Manual simulator verification covers rendering/interaction.

## Linting

- `.swiftlint.yml` at the repo root defines the ruleset (see file for
  specifics: line length, force-unwrap ban outside tests, explicit `self`
  avoided, cyclomatic complexity warnings).
- SwiftLint is a **developer-time tool only** — it is not linked into the
  app and does not affect the shipped binary, consistent with the
  "no third-party libraries" constraint (it's invoked via a build phase
  script that no-ops gracefully if the tool isn't installed, so the project
  still builds on a machine without it).

## Trade-offs log

| Decision | Trade-off accepted | Why |
|---|---|---|
| Single `PersistedEvent` SwiftData model (no separate Bookmark entity) | Slightly conflates "cached event" and "bookmarked event" concerns in one table | Simpler schema/migrations for this scope; a real product with sync would likely split these, but one model with an `isBookmarked` flag is enough to satisfy "persist bookmarks and last-fetched events" without over-engineering |
| "Past" segment queries one day at a time (the selected date), not a trailing window | Selecting a date far outside the ~30-day non-bookmarked retention window will show nothing from local cache — though the network query itself is unaffected by pruning | Mirrors "Upcoming" exactly for a consistent mental model: pick a day, see what happened/is happening that day. A rolling window ignored the date strip entirely, which was the reported bug this replaced |
| Events without a venue are dropped from every repository response | Ticketmaster's digital-content/download listings never appear, even though they're technically valid catalog entries | Confirmed via direct API testing: these share one generic placeholder image and have no location — useless in a *local* events app, and distance/maps features need a venue anyway |
| Response cache TTL (10 min) vs. image cache TTL (7 days) | Two different cache lifetimes to reason about | Event listings churn; event artwork doesn't — a single shared TTL would be wrong for one of the two |
| API key in a gitignored `Secrets.swift` | Key still ships inside the compiled binary and is technically extractable by a determined attacker | No third-party libraries allowed rules out a secrets-management SDK; a real production app would proxy Ticketmaster calls through a backend that holds the key server-side — called out explicitly as the next step |
| No third-party libraries | More code to write for caching/networking/image loading than `Kingfisher`/`Alamofire` would require | Explicit assignment constraint; also demonstrates the underlying platform APIs directly, which is the point of the exercise |
| Home prefetches every day in the date strip on launch, not just the selected one | Up to 6 extra background network calls per launch, all before any of those days might ever be viewed | Live testing proved the Discovery API's date filtering is unreliable for backward-looking queries (0/6 correctly-dated results across past days and radii up to 150mi) — real data for a past day only exists if it was captured while that day was still current. Fired from its own concurrent `.task` so it never delays the initial screen or the location primer |
| Background refresh best-effort, low frequency | Data can be up to ~4h+ stale before an app open | Matches "low frequency" requirement and iOS's own `BGTaskScheduler` budget realities — the OS does not guarantee exact timing regardless of what we request |
| Upcoming/Past queries fall back to a hardcoded city (`DefaultLocation`, Toronto) when no live device location is available | "Nearby" isn't actually nearby for a user physically located elsewhere until they grant permission or the Simulator's location is set | Without *some* geo filter, Ticketmaster's global catalog returns evergreen/digital listings that don't match any requested day (confirmed via direct API testing — see `DefaultLocation.swift`); a real product would derive this from locale/timezone or IP geolocation instead of one hardcoded coordinate. Never used for the on-device distance shown on the detail screen — that stays absent rather than showing a number computed from a fallback |
