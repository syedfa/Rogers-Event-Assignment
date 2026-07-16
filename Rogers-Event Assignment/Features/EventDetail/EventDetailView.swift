import SwiftUI

struct EventDetailView: View {
    @StateObject var viewModel: EventDetailViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                RemoteImage(url: viewModel.event.imageURL) {
                    Rectangle().fill(Color.secondary.opacity(0.15))
                }
                .aspectRatio(16.0 / 9.0, contentMode: .fill)
                .frame(maxWidth: .infinity)
                .clipped()

                VStack(alignment: .leading, spacing: 14) {
                    Text(viewModel.event.title)
                        .font(.title2.bold())

                    if let category = viewModel.event.category {
                        Text(category)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if let startDate = viewModel.event.startDate {
                        Label {
                            Text(startDate, format: .dateTime.weekday(.wide).month().day().hour().minute())
                        } icon: {
                            Image(systemName: "calendar")
                        }
                    }

                    if let venue = viewModel.event.venue {
                        VStack(alignment: .leading, spacing: 6) {
                            Label(venue.name, systemImage: "mappin.and.ellipse")
                            if let distanceText = viewModel.distanceText {
                                Text(distanceText)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .padding(.leading, 24)
                            }
                        }

                        Button {
                            viewModel.openInMaps()
                        } label: {
                            Label("Open in Maps", systemImage: "map")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }

                    bookmarkButton
                }
                .padding()
            }
        }
        .task { await viewModel.onAppear() }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
    }

    private var bookmarkButton: some View {
        Button {
            Task { await viewModel.toggleBookmark() }
        } label: {
            Label(
                viewModel.event.isBookmarked ? "Bookmarked" : "Bookmark this event",
                systemImage: viewModel.event.isBookmarked ? "heart.fill" : "heart"
            )
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(viewModel.event.isBookmarked ? .red : .accentColor)
        .controlSize(.large)
        .accessibilityLabel(viewModel.event.isBookmarked ? "Remove bookmark" : "Add bookmark")
    }
}
