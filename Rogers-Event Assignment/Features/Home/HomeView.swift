import CoreLocation
import SwiftUI

struct HomeView: View {
    @StateObject var viewModel: HomeViewModel
    let makeDetailViewModel: (Event) -> EventDetailViewModel

    @State private var selectedEvent: Event?
    @State private var showingLocationPrimer = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                DateStripView(days: viewModel.dateStripDays, selectedDate: viewModel.selectedDate) { day in
                    Task { await viewModel.select(date: day) }
                }

                Picker("Segment", selection: segmentBinding) {
                    ForEach(EventSegment.allCases) { segment in
                        Text(segment.title).tag(segment)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                LoadStateView(
                    state: viewModel.state,
                    retry: { await viewModel.load() },
                    content: { events in
                        if events.isEmpty {
                            EmptyStateView(segment: viewModel.selectedSegment)
                        } else {
                            eventList(events)
                        }
                    }
                )
            }
            .navigationTitle("Local Events")
            .task {
                await viewModel.onAppear()
                // Must be checked explicitly after the initial load, not via
                // .onChange(of:) — onChange never fires for a value's *initial*
                // state, and .notDetermined is exactly the state we're checking for
                // on first launch. Relying on onChange alone means the primer (and
                // therefore the location permission request and distance-to-event
                // feature) never appears at all.
                if viewModel.locationAuthorizationStatus == .notDetermined {
                    showingLocationPrimer = true
                }
            }
            .task {
                // Runs concurrently with the .task above, not after it — warming
                // the rest of the date strip in the background must never delay
                // the initial screen or the location primer.
                await viewModel.prefetchDateStripDays()
            }
            .onChange(of: viewModel.locationAuthorizationStatus) { _, status in
                if status == .notDetermined {
                    showingLocationPrimer = true
                }
            }
            .sheet(isPresented: $showingLocationPrimer) {
                LocationPrimerView(
                    onContinue: {
                        showingLocationPrimer = false
                        await viewModel.requestLocationPermission()
                    },
                    onSkip: { showingLocationPrimer = false }
                )
                .presentationDetents([.medium])
            }
            .sheet(
                item: $selectedEvent,
                onDismiss: { Task { await viewModel.load() } },
                content: { event in
                    // The detail screen bookmarks directly against EventStore, bypassing
                    // HomeViewModel entirely — without this reload on dismiss, the
                    // card's heart would keep showing whatever was true when the list
                    // last loaded.
                    NavigationStack {
                        EventDetailView(viewModel: makeDetailViewModel(event))
                    }
                }
            )
        }
    }

    private var segmentBinding: Binding<EventSegment> {
        Binding(
            get: { viewModel.selectedSegment },
            set: { newValue in Task { await viewModel.select(segment: newValue) } }
        )
    }

    private func eventList(_ events: [Event]) -> some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                ForEach(events) { event in
                    EventCardView(
                        event: event,
                        distanceText: viewModel.distanceText(for: event),
                        onToggleBookmark: {
                            Task { await viewModel.toggleBookmark(for: event) }
                        }
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { selectedEvent = event }
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
    }
}

private struct EmptyStateView: View {
    let segment: EventSegment

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: segment == .bookmarked ? "heart" : "calendar")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var message: String {
        switch segment {
        case .explore: return "No events found for this day."
        case .bookmarked: return "Bookmark events to see them here."
        }
    }
}
