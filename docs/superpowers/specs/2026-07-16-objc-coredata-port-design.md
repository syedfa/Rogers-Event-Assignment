# Objective-C + Core Data Port — Design

## Context

The Swift/SwiftUI/SwiftData "Local Events Explorer" app (`Rogers-Event Assignment/`)
is complete: full feature set, 80+ passing unit tests, clean lint, docs. The user
asked for an **identical version built in Objective-C with Core Data**, in a new
sibling folder `Rogers-Event Assignment - ObjC/`.

"Identical" means full behavioral parity — every feature and every bug fix made
during the Swift build (weekend highlighting, Past-tab semantics including the
"already started counts as past" rule, distance-based sorting, image/response
caching with TTL, background refresh, location primer, retry/backoff, the
bookmark-sync-on-dismiss fix, venue-less event filtering, default-location
fallback) — not just the original feature list. It is **not** a line-by-line
transliteration: SwiftUI, Swift Concurrency, `Codable`, and Swift Testing have no
Objective-C equivalent, so those layers are re-architected using the idiomatic
Objective-C tool for the same job (see Technology Mapping below). Everything
else — layering, DI, caching strategy, retry policy, the exact Past/Upcoming
query semantics — carries over unchanged.

## Decisions (confirmed with user)

1. **Full parity**, not a reduced core-features MVP.
2. **Own gitignored `Secrets.h`** (+ committed `Secrets.h.example`), independent
   of the Swift app's `Secrets.swift`.
3. **Tests first (TDD)**: full `XCTest` suite written and confirmed red before
   implementation, mirroring the Swift project's process.
4. New, fully independent Xcode project (own `.xcodeproj`, scheme, targets),
   generated via `xcodegen` (installed via Homebrew) from a `project.yml` spec —
   not hand-written `pbxproj` XML, and not a second target inside the existing
   Swift project.

## Technology mapping (necessary translations)

| Swift concern | Objective-C equivalent | Why |
|---|---|---|
| SwiftUI views | UIKit (`UIViewController` + `UITableView`/`UICollectionView`) | SwiftUI's declarative syntax relies on Swift-only language features (result builders, property wrappers) — there is no Objective-C SwiftUI |
| `async`/`await`, `actor` | GCD: completion-handler blocks + a private serial `dispatch_queue_t` per cache/store for thread confinement | Objective-C has no coroutines or actor isolation |
| `Codable` | Manual `+modelFromJSON:` class constructors on each DTO, parsing `NSDictionary` | No reflection-based decoding in Objective-C |
| `enum` with associated values (`APIError`, `LoadState<Value>`) | `NSError` with a custom domain + `NS_ENUM` codes (statusCode etc. in `userInfo`) for errors; a small `RGLoadState` class (`RGLoadStateKind` enum + `id` payload properties) for the state machine | Objective-C enums are plain integers, no associated values |
| Swift Testing (`@Test`, `#expect`) | `XCTest` (`XCTestCase`, `XCTAssert*`); async completion-block calls tested via `XCTestExpectation`/`waitForExpectationsWithTimeout:` | Swift Testing's macros are Swift-only |
| `@Published`/`ObservableObject` | Delegate-callback pattern: each ViewModel defines a delegate protocol (e.g. `RGHomeViewModelDelegate` with `-viewModel:didUpdateState:`) that the owning view controller implements | No Combine/SwiftUI observation without extra plumbing; delegate pattern is the standard pre-Combine Objective-C MVVM idiom |

Everything **not** in this table (DI via `AppDependencies`-equivalent composition
root, protocol-oriented services, the repository's stale-while-revalidate flow,
`RetryPolicy`'s backoff math, the exact Past-segment "already started" filtering,
venue-less event exclusion, response/image cache TTL split, background refresh
scheduling, location-permission priming) is preserved exactly as designed in the
Swift version — same values, same predicates, same trade-offs.

## Project setup

- New sibling folder: `Rogers-Event Assignment - ObjC/`
- Generated with `xcodegen generate` from a `project.yml`:
  - App target: `Rogers-Event Assignment - ObjC` (UIKit, iOS 17+ deployment to
    match Core Data/BGTaskScheduler API availability used)
  - Unit test target: `Rogers-Event Assignment - ObjCTests` (XCTest, hosted in
    the app target so it can `#import` app headers directly — the Objective-C
    equivalent of `@testable import`)
  - UI test target: skeleton only, not a focus of this port
- `Secrets.h` (gitignored) + `Secrets.h.example` (committed) — same pattern as
  the Swift app. `.gitignore` extended to cover the new path.
- `.clang-format` (LLVM-provided, no install required) committed as the
  style-consistency equivalent of `.swiftlint.yml`; documented as a
  developer-time-only tool, same framing as SwiftLint in the Swift project.

## Core Data schema

One `.xcdatamodeld` (hand-authored XML — a much simpler, more tolerant format
than `pbxproj`) defining a single `PersistedEvent` entity, matching the
SwiftData model's fields exactly:

`id` (String, unique), `title` (String), `category` (String, optional),
`startDate` (Date, optional), `timeZoneIdentifier` (String, optional),
`imageURLString` (String, optional), `infoURLString` (String, optional),
`venueName` (String, optional), `venueAddress` (String, optional),
`venueCity` (String, optional), `venueLatitude` (Double, optional),
`venueLongitude` (Double, optional), `isBookmarked` (Bool), `fetchedAt` (Date).

`RGCoreDataStack` wraps `NSPersistentContainer`; supports an in-memory store
(`NSInMemoryStoreType`) for tests, mirroring SwiftData's
`isStoredInMemoryOnly: true`.

## Layer-by-layer file mapping

Same directory shape as the Swift project (`App/`, `Core/{Networking,Cache,
Location,Persistence,Background,Support}/`, `Domain/`, `Repository/`,
`Features/{Home,EventDetail,Shared}/`), `RG`-prefixed per Objective-C
convention, each Swift file becoming one or more `.h`/`.m` pairs:

- **App**: `RGAppDependencies`, `RGAppConfig` / `RGSecretsProviding`,
  `AppDelegate` / `SceneDelegate` (UIKit lifecycle, replaces
  `RogersEventAssignmentApp.swift`'s `@main App`)
- **Core/Networking**: `RGAPIError`, `RGLoadState`, `RGRetryPolicy`,
  `RGTicketmasterEndpoint`, `RGNetworkService` / `RGURLSessionNetworkService`
- **Core/Cache**: `RGResponseCache`, `RGImageCache` (GCD-queue-isolated, TTL via
  injected `RGClock`, memory + disk tiers — same design as Swift)
- **Core/Location**: `RGLocationService` / `RGCoreLocationService`,
  `RGDistanceFormatter`, `RGDefaultLocation`
- **Core/Persistence**: `RGCoreDataStack`, `RGPersistedEvent`
  (+CoreDataProperties), `RGEventStore` / `RGCoreDataEventStore`
- **Core/Background**: `RGBackgroundRefreshScheduler` (same `BGAppRefreshTask`
  API — available to Objective-C)
- **Core/Support**: `RGClock` / `RGSystemClock`, `NSString+RGHashing`
  (CommonCrypto SHA-256 — native, no library)
- **Domain**: `RGEvent` / `RGVenue` (immutable value-like classes implementing
  `-isEqual:`/`-hash`), `RGTicketmasterEventDTO` + related DTO classes (manual
  JSON parsing + `-toDomainEvent`)
- **Repository**: `RGEventsRepository` / `RGDefaultEventsRepository` — same
  `fetchUpcoming`/`fetchPast`/`refreshUpcomingNearby` methods, same
  window-filtering and Past "already started" logic, block-based completions
- **Features/Home**: `RGHomeViewController`, `RGHomeViewModel` (delegate
  callback replacing `@Published`), `RGDateStripView`, `RGEventCardCell`,
  `RGEventSegment`
- **Features/EventDetail**: `RGEventDetailViewController`,
  `RGEventDetailViewModel`
- **Features/Shared**: `RGLoadStateView`, `RGLocationPrimerViewController`,
  `RGMissingAPIKeyViewController`, `RGRemoteImageView`

## Testing strategy

Full `XCTest` suite mirroring every Swift Testing file in scope: retry/backoff,
load state transitions, endpoint URL building, JSON→domain mapping (incl. the
best-image-selection and missing-field tolerance), both caches' TTL expiry
(memory + disk, injected clock), repository orchestration (cache hit/miss,
stale-while-revalidate, the exact Past "already started today" vs "later today
excluded" vs "future day empty, no network call" rules), the Core Data store
(upsert-preserves-bookmark, bookmark round-trip, prune-never-deletes-bookmarked
invariant), and both ViewModels. Async block-based APIs are tested via
`XCTestExpectation`. Tests-first: compilable stub headers + empty `.m` bodies
first, full test suite written and run to confirm red, then implementation to
green — same discipline as the Swift build.

## Docs deliverables

Same set as the Swift project, adapted for the language/framework: `README.md`
(run steps incl. `cp Secrets.h.example Secrets.h`, ObjC-specific setup notes),
`docs/ARCHITECTURE.md`, `docs/SEQUENCE.md`, `docs/ENGINEERING_STANDARDS.md`
(including a trade-offs log covering the technology-mapping decisions above,
in the same voice/format as the Swift project's log).

## Verification

- `xcodebuild test -project "Rogers-Event Assignment - ObjC.xcodeproj" -scheme "Rogers-Event Assignment - ObjC" -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` — full suite green.
- Build & launch in simulator; live-verify against the real Ticketmaster API the
  same way the Swift app was verified (date strip, segments, bookmark
  persistence/sync, distance sort, location primer, maps deep link).
- `clang-format --dry-run` (or equivalent) shows no diffs against the committed
  style.
- `git status` confirms `Secrets.h` untracked.

## Scope note

This is a large port — effectively a second full application. Expect it to
span multiple implementation sessions/turns rather than a single pass; the plan
that follows this spec will sequence it the same way the original build was
sequenced (docs → tests → Core layer → Domain/Repository → Features → app
wiring → polish).
