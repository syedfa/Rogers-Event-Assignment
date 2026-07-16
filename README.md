# Local Events Explorer

A native iOS app (SwiftUI, SwiftData, no third-party libraries) that lists nearby
events from the Ticketmaster Discovery API, lets you bookmark them, and shows
event details with distance and a native Maps deep link.

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for the architecture diagram,
[`docs/SEQUENCE.md`](docs/SEQUENCE.md) for sequence diagrams of the main flows,
and [`docs/ENGINEERING_STANDARDS.md`](docs/ENGINEERING_STANDARDS.md) for
conventions and the trade-offs log.

## Features

- **Home**: date strip + Upcoming / Past / Saved segmented control, event cards
  with image, title, category, date, venue, and a bookmark heart.
- **Event detail**: hero image, full info, distance to venue, "Open in Maps",
  and a prominent (un)Bookmark button.
- **Bookmarks**: persisted in SwiftData, never purged by the background prune,
  and work fully offline.
- **Caching**: API responses (10 min TTL) and images (7 day TTL) each have a
  memory + disk tier, fully native (`NSCache`, `FileManager`, `URLSession`).
- **Location**: contextual pre-permission screen, distance shown when granted,
  graceful degradation when not.
- **Background refresh**: low-frequency `BGAppRefreshTask` keeps Upcoming data
  warm and prunes stale cache entries.
- **Unified networking**: one `NetworkService` with retry/backoff
  (`RetryPolicy`) and one `LoadState<Value>` state machine used by every
  ViewModel — retry logic and loading/error UI are written exactly once.

## Requirements

- Xcode 26+ (project uses `objectVersion 77` / file-system-synchronized
  groups — Xcode 16 or newer required)
- iOS 26.2+ simulator or device
- A [Ticketmaster Discovery API key](https://developer.ticketmaster.com/) (free tier is enough)

## Run steps

1. Open `Rogers-Event Assignment.xcodeproj` in Xcode.
2. Copy the secrets template and add your API key:
   ```sh
   cp "Rogers-Event Assignment/App/Secrets.swift.example" "Rogers-Event Assignment/App/Secrets.swift"
   ```
   Edit `Secrets.swift` and replace `YOUR_TICKETMASTER_API_KEY` with your real
   key. **`Secrets.swift` is gitignored — it will never be committed.** If you
   skip this step the app still builds and runs; it shows a friendly
   "add your API key" screen instead of crashing.
3. Select the `Rogers-Event Assignment` scheme and a simulator, then **Run**
   (⌘R).
4. On first launch, tap "Enable Location" on the primer screen to see
   distance-to-event; "Not Now" also works — the list still functions without
   it, just without distances.

### Running tests

```sh
xcodebuild test \
  -scheme "Rogers-Event Assignment" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Or ⌘U in Xcode. All core logic (networking, caching, persistence, mapping,
ViewModels) is covered by unit tests using Swift Testing — see
[`Rogers-Event AssignmentTests`](Rogers-Event%20AssignmentTests).

### Linting

```sh
brew install swiftlint   # optional, dev-time only
```

A build phase runs SwiftLint automatically if it's installed, and just prints
a warning (never fails the build) if it isn't. Config: [`.swiftlint.yml`](.swiftlint.yml).

## API key security

The key lives in a gitignored `Secrets.swift`, read at compile time through a
`SecretsProviding` protocol — it never touches source control. That said, any
key embedded in a client binary is technically extractable by a determined
attacker via static analysis; keeping it out of git avoids the much more
common leak vector (public repos, commit history, forks), but it is **not** a
substitute for a real secret. The production-correct fix — out of scope for
this assignment's local-only deliverable — is a thin server-side proxy that
holds the real key and authenticates/rate-limits the app's own requests
instead of the app talking to Ticketmaster directly.

## Project structure

```
Rogers-Event Assignment/
  App/            Composition root, entry point, secrets
  Core/           Networking, Cache, Location, Persistence, Background — all protocol-first
  Domain/         Event/Venue models + Ticketmaster DTO mapping
  Repository/     EventsRepository (network + cache + SwiftData orchestration)
  Features/       Home, EventDetail, Shared SwiftUI views + ViewModels
docs/             Architecture diagram, sequence diagrams, engineering standards
```

## Known trade-offs

See the trade-offs log in
[`docs/ENGINEERING_STANDARDS.md`](docs/ENGINEERING_STANDARDS.md#trade-offs-log)
for the reasoning behind decisions like the single SwiftData model, the
Past segment's 30-day trailing window, filtering out venue-less
events, and the client-side API key.
