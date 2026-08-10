//
//  ShareImageLoader.swift
//  Brackets
//

import UIKit

/// Downloads remote images into `UIImage` up front.
///
/// The app renders logos with `AsyncImage` everywhere else, but `ImageRenderer`
/// snapshots synchronously — an `AsyncImage` that hasn't resolved exports as a blank
/// placeholder. So anything that needs to appear in a shared image must come through
/// here first.
///
/// Scoped deliberately to sharing; this is not a general replacement for the app's
/// `AsyncImage` usage.
actor ShareImageLoader {

    static let shared = ShareImageLoader()

    private let cache = NSCache<NSString, UIImage>()
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = AppConfig.API.requestTimeout
        config.requestCachePolicy = .returnCacheDataElseLoad
        self.session = URLSession(configuration: config)
        cache.countLimit = 60
    }

    /// Loads one image, returning `nil` for a missing/invalid URL or any failure.
    /// Callers are expected to fall back to an initials placeholder.
    func load(_ urlString: String?) async -> UIImage? {
        guard let urlString, !urlString.isEmpty, let url = URL(string: urlString) else { return nil }

        let key = urlString as NSString
        if let cached = cache.object(forKey: key) { return cached }

        do {
            let (data, response) = try await session.data(from: url)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                return nil
            }
            guard let image = UIImage(data: data) else { return nil }
            cache.setObject(image, forKey: key)
            return image
        } catch {
            return nil
        }
    }

    /// Loads several images concurrently, preserving the order of `urls`.
    /// A failed entry comes back as `nil` rather than failing the whole batch.
    func load(_ urls: [String?]) async -> [UIImage?] {
        await withTaskGroup(of: (Int, UIImage?).self) { group in
            for (index, url) in urls.enumerated() {
                group.addTask { (index, await self.load(url)) }
            }

            var results = [UIImage?](repeating: nil, count: urls.count)
            for await (index, image) in group {
                results[index] = image
            }
            return results
        }
    }
}
