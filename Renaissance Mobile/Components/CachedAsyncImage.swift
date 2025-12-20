//
//  CachedAsyncImage.swift
//  Renaissance Mobile
//
//  Created by Nu Le on 12/20/25.
//

import SwiftUI

/// AsyncImage with built-in caching to avoid unnecessary network requests
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder

    @State private var image: UIImage?
    @State private var isLoading = false

    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let image = image {
                content(Image(uiImage: image))
            } else {
                placeholder()
                    .task {
                        await loadImage()
                    }
            }
        }
    }

    private func loadImage() async {
        guard let url = url else { return }
        guard !isLoading else { return }

        isLoading = true
        defer { isLoading = false }

        let urlString = url.absoluteString

        // Check cache first
        if let cachedImage = ImageCache.shared.getImage(for: urlString) {
            await MainActor.run {
                self.image = cachedImage
            }
            return
        }

        // Download from network
        do {
            let (data, _) = try await URLSession.shared.data(from: url)

            guard let downloadedImage = UIImage(data: data) else {
                print("❌ Failed to create image from data")
                return
            }

            // Cache the image
            ImageCache.shared.setImage(downloadedImage, for: urlString)

            // Update UI
            await MainActor.run {
                self.image = downloadedImage
            }
        } catch {
            print("❌ Failed to load image: \(error.localizedDescription)")
        }
    }
}

// MARK: - Convenience Initializer

extension CachedAsyncImage where Content == Image, Placeholder == Color {
    init(url: URL?) {
        self.init(
            url: url,
            content: { $0 },
            placeholder: { Color.gray.opacity(0.2) }
        )
    }
}
