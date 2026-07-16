import SwiftUI

/// Event card per the provided design: hero image with a heart bookmark toggle
/// overlaid top-trailing, title, category/date line, venue.
struct EventCardView: View {
    let event: Event
    let distanceText: String?
    let onToggleBookmark: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                RemoteImage(url: event.imageURL) {
                    Rectangle().fill(Color.secondary.opacity(0.15))
                }
                .aspectRatio(16.0 / 9.0, contentMode: .fill)
                .frame(maxWidth: .infinity)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 16))

                Button(action: onToggleBookmark) {
                    Image(systemName: event.isBookmarked ? "heart.fill" : "heart")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(event.isBookmarked ? .red : .white)
                        .padding(10)
                        .background(.black.opacity(0.35), in: Circle())
                }
                .padding(10)
                .accessibilityLabel(event.isBookmarked ? "Remove bookmark" : "Add bookmark")
            }

            Text(event.title)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(2)

            HStack(spacing: 6) {
                if let category = event.category {
                    Text(category)
                    if event.startDate != nil {
                        Text("•")
                    }
                }
                if let startDate = event.startDate {
                    Text(startDate, style: .date)
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            if event.venue?.name != nil || distanceText != nil {
                HStack(spacing: 6) {
                    if let venueName = event.venue?.name {
                        Text(venueName)
                    }
                    if let distanceText {
                        if event.venue?.name != nil {
                            Text("•")
                        }
                        Label(distanceText, systemImage: "location.fill")
                            .labelStyle(.titleAndIcon)
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
        }
    }
}
