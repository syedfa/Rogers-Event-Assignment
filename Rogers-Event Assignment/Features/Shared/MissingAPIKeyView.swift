import SwiftUI

/// Friendly runtime state shown instead of crashing when `Secrets.swift` still has
/// the placeholder value from `Secrets.swift.example`. See README for setup steps.
struct MissingAPIKeyView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "key.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Ticketmaster API Key Needed")
                .font(.title2.bold())
            Text("Copy Secrets.swift.example to Secrets.swift and add your Ticketmaster Discovery API key, then rebuild.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding()
    }
}
