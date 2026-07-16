import SwiftUI

/// Shown before the system location permission dialog, explaining *why* we're
/// asking. Apple HIG best practice for conversion: a contextual, in-app primer
/// measurably improves opt-in rates versus a cold system prompt with no context,
/// and lets the user say "not now" without burning the one-shot system dialog.
struct LocationPrimerView: View {
    let onContinue: () async -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "location.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            Text("See events near you")
                .font(.title2.bold())
            Text(
                "We use your location only to show distance to events and sort them by proximity. " +
                "You can change this anytime in Settings."
            )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            Button {
                Task { await onContinue() }
            } label: {
                Text("Enable Location")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal)

            Button("Not Now", action: onSkip)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .padding(.bottom, 24)
        }
    }
}
