import SwiftUI

private struct ImageCacheKey: EnvironmentKey {
    static let defaultValue: ImageCache? = nil
}

extension EnvironmentValues {
    var imageCache: ImageCache? {
        get { self[ImageCacheKey.self] }
        set { self[ImageCacheKey.self] = newValue }
    }
}

/// Loads a remote image through `ImageCache` (memory + disk, TTL) instead of
/// re-downloading on every appearance. Fully native — `URLSession` + `NSCache` +
/// `FileManager`, no third-party image-loading library.
struct RemoteImage<Placeholder: View>: View {
    let url: URL?
    @ViewBuilder var placeholder: () -> Placeholder

    @Environment(\.imageCache) private var imageCache
    @State private var uiImage: UIImage?

    var body: some View {
        Group {
            if let uiImage {
                Image(uiImage: uiImage)
                    .resizable()
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            uiImage = nil
            await load()
        }
    }

    private func load() async {
        guard let url, let imageCache else { return }

        if let cached = await imageCache.image(for: url), let image = UIImage(data: cached) {
            uiImage = image
            return
        }

        guard let (data, response) = try? await URLSession.shared.data(from: url),
              let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let image = UIImage(data: data) else {
            return
        }

        await imageCache.store(data, for: url)
        uiImage = image
    }
}
