import SwiftUI

/// Renders any `LoadState<Value>` uniformly across every screen: a loading spinner
/// when there's nothing to show yet, content once loaded, and — on failure — the
/// last-known-good content (if any) with an inline "couldn't refresh" banner and
/// retry, rather than blanking the screen out from under the user.
struct LoadStateView<Value: Equatable & Sendable, Content: View>: View {
    let state: LoadState<Value>
    let retry: () async -> Void
    @ViewBuilder var content: (Value) -> Content

    var body: some View {
        switch state {
        case .idle:
            Color.clear
        case .loading(let previous):
            if let previous {
                content(previous)
            } else {
                ProgressView("Loading events…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        case .loaded(let value):
            content(value)
        case .failed(let error, let previous):
            if let previous {
                VStack(spacing: 0) {
                    FailureBanner(error: error, retry: retry)
                    content(previous)
                }
            } else {
                FailureView(error: error, retry: retry)
            }
        }
    }
}

private struct FailureBanner: View {
    let error: APIError
    let retry: () async -> Void

    var body: some View {
        HStack {
            Text("Couldn't refresh — showing saved results")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Retry") { Task { await retry() } }
                .font(.footnote)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.yellow.opacity(0.15))
    }
}

private struct FailureView: View {
    let error: APIError
    let retry: () async -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Retry") { Task { await retry() } }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var message: String {
        switch error {
        case .network:
            return "No connection. Check your network and try again."
        case .unauthorized:
            return "This app needs a Ticketmaster API key. Add one to Secrets.swift and rebuild."
        case .server, .invalidRequest, .decoding, .cancelled:
            return "Something went wrong loading events."
        }
    }
}
