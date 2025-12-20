//
//  ImageCache.swift
//  Renaissance Mobile
//
//  Created by Nu Le on 12/20/25.
//

import UIKit

/// Singleton cache for profile images to avoid unnecessary network requests
class ImageCache {
    static let shared = ImageCache()

    private let cache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL

    private init() {
        // Set up disk cache directory
        let paths = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        cacheDirectory = paths[0].appendingPathComponent("ProfileImages")

        // Create directory if it doesn't exist
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        // Exclude from iCloud backup (cache data can be regenerated)
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        var mutableCacheDirectory = cacheDirectory
        try? mutableCacheDirectory.setResourceValues(resourceValues)

        // Configure memory cache limits
        cache.countLimit = 100 // Maximum 100 images in memory
        cache.totalCostLimit = 50 * 1024 * 1024 // 50 MB max
    }

    // MARK: - Public Methods

    /// Get cached image for URL
    func getImage(for url: String) -> UIImage? {
        let key = cacheKey(for: url)

        // Check memory cache first
        if let cachedImage = cache.object(forKey: key as NSString) {
            print("📸 Image cache HIT (memory): \(url)")
            return cachedImage
        }

        // Check disk cache
        if let diskImage = loadFromDisk(key: key) {
            // Store in memory for faster access next time
            cache.setObject(diskImage, forKey: key as NSString)
            print("📸 Image cache HIT (disk): \(url)")
            return diskImage
        }

        print("📸 Image cache MISS: \(url)")
        return nil
    }

    /// Cache image for URL
    func setImage(_ image: UIImage, for url: String) {
        let key = cacheKey(for: url)

        // Store in memory cache
        cache.setObject(image, forKey: key as NSString)

        // Store on disk asynchronously
        Task.detached(priority: .background) { [weak self] in
            self?.saveToDisk(image: image, key: key)
        }

        print("📸 Image cached: \(url)")
    }

    /// Remove cached image for URL
    func removeImage(for url: String) {
        let key = cacheKey(for: url)

        // Remove from memory
        cache.removeObject(forKey: key as NSString)

        // Remove from disk
        let fileURL = cacheDirectory.appendingPathComponent(key)
        try? fileManager.removeItem(at: fileURL)

        print("📸 Image removed from cache: \(url)")
    }

    /// Clear all cached images
    func clearCache() {
        // Clear memory cache
        cache.removeAllObjects()

        // Clear disk cache
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        print("📸 All cached images cleared")
    }

    // MARK: - Private Methods

    private func cacheKey(for url: String) -> String {
        // Use SHA256 hash of URL as cache key to avoid invalid file names
        return url.sha256()
    }

    private func loadFromDisk(key: String) -> UIImage? {
        let fileURL = cacheDirectory.appendingPathComponent(key)

        guard let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data) else {
            return nil
        }

        return image
    }

    private func saveToDisk(image: UIImage, key: String) {
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            return
        }

        let fileURL = cacheDirectory.appendingPathComponent(key)
        try? data.write(to: fileURL)
    }
}

// MARK: - String Extension for SHA256

extension String {
    func sha256() -> String {
        guard let data = self.data(using: .utf8) else { return self }

        // Simple hash function (for cache key generation)
        var hash = 0
        for byte in data {
            hash = ((hash << 5) &- hash) &+ Int(byte)
        }

        return String(format: "%016x", abs(hash))
    }
}
