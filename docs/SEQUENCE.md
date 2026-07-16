# Sequence Diagrams

## 1. Cold launch → Upcoming events (cache miss, then hit on revisit)

```mermaid
sequenceDiagram
    actor User
    participant Home as HomeView
    participant VM as HomeViewModel
    participant Repo as EventsRepository
    participant Cache as ResponseCache
    participant Net as NetworkService
    participant Retry as RetryPolicy
    participant API as Ticketmaster API
    participant Store as EventStore (SwiftData)

    User->>Home: Launch app (Upcoming, today selected)
    Home->>VM: onAppear
    VM->>VM: state = .loading(previous: nil)
    VM->>Repo: events(for: today, segment: .upcoming)
    Repo->>Cache: lookup(key: endpoint)
    Cache-->>Repo: miss
    Repo->>Net: request(TicketmasterEndpoint)
    Net->>Retry: shouldRetry / delay(for: attempt)
    Net->>API: GET /discovery/v2/events.json?...
    API-->>Net: 200 OK + JSON
    Net-->>Repo: decoded EventsResponse
    Repo->>Cache: store(response, ttl: 10m)
    Repo->>Store: upsert(events)
    Repo-->>VM: .loaded([Event])
    VM->>VM: state = .loaded([Event])
    VM-->>Home: publish change
    Home-->>User: render event cards

    Note over User,Home: User backgrounds and reopens app within 10 min
    User->>Home: Reopen (Upcoming, today)
    Home->>VM: onAppear
    VM->>Repo: events(for: today, segment: .upcoming)
    Repo->>Cache: lookup(key: endpoint)
    Cache-->>Repo: hit (fresh)
    Repo-->>VM: .loaded([Event]) (no network call)
    VM-->>Home: render immediately
```

## 2. Network failure with retry, falling back to cached data

```mermaid
sequenceDiagram
    participant VM as HomeViewModel
    participant Repo as EventsRepository
    participant Cache as ResponseCache
    participant Net as NetworkService
    participant Retry as RetryPolicy
    participant API as Ticketmaster API

    VM->>Repo: events(for: date, segment: .upcoming)
    Repo->>Cache: lookup(key: endpoint)
    Cache-->>Repo: hit (stale, past TTL)
    Repo-->>VM: .loaded(previous) [stale-while-revalidate: emit immediately]
    Repo->>Net: request(TicketmasterEndpoint) [revalidate in background]

    loop up to maxAttempts
        Net->>API: GET events
        API-->>Net: connection timeout
        Net->>Retry: isRetryable(error)?
        Retry-->>Net: yes, attempt < max
        Net->>Net: await delay(backoff + jitter)
    end

    Net->>API: GET events (final attempt)
    API-->>Net: connection timeout
    Net->>Retry: isRetryable / attempt == max
    Retry-->>Net: exhausted
    Net-->>Repo: .failure(APIError.network)
    Repo-->>VM: .failed(.network, previous: [Event])
    VM->>VM: state = .failed(.network, previous: [Event])
    Note over VM: UI shows cached list + inline\n"Couldn't refresh — showing saved results" + Retry button
```

## 3. Bookmark toggle (card and detail — single source of truth)

```mermaid
sequenceDiagram
    actor User
    participant Card as EventCardView
    participant Detail as EventDetailView
    participant DVM as EventDetailViewModel
    participant Store as EventStore (SwiftData)

    User->>Card: Tap heart on event card
    Card->>Store: setBookmarked(true, for: eventID)
    Store->>Store: fetch PersistedEvent, isBookmarked = true, save
    Store-->>Card: (SwiftData @Query auto-refreshes bound views)

    User->>Detail: Open event, tap "Bookmark" button
    Detail->>DVM: toggleBookmark()
    DVM->>Store: setBookmarked(!current, for: eventID)
    Store->>Store: fetch PersistedEvent, flip isBookmarked, save
    Store-->>DVM: updated Event
    DVM-->>Detail: state.isBookmarked updates, button label flips
    Note over Card,Detail: Both views read through the same EventStore,\nso either entry point stays consistent with the other.
```

## 4. Background refresh (low frequency)

```mermaid
sequenceDiagram
    participant OS as iOS BGTaskScheduler
    participant Sched as BackgroundRefreshScheduler
    participant Repo as EventsRepository
    participant Store as EventStore (SwiftData)
    participant Net as NetworkService

    Note over OS: earliestBeginDate ~4h out, OS decides actual fire time
    OS->>Sched: launch handler for ca.cybermedia...refresh
    Sched->>Sched: schedule next BGAppRefreshTaskRequest
    Sched->>Repo: refreshUpcoming(nearLastKnownLocation)
    Repo->>Net: request(TicketmasterEndpoint) [bypasses response cache]
    Net-->>Repo: EventsResponse (or failure — swallowed, not surfaced)
    Repo->>Store: upsert(events)
    Sched->>Store: prune(olderThan: 30d, excludingBookmarked: true)
    Sched->>OS: task.setTaskCompleted(success:)
    Note over Sched: Expiration handler cancels the in-flight\nrepository call if the OS revokes background time.
```
