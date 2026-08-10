//
//  ShareDestinations.swift
//  Brackets
//

import Photos
import SwiftUI
import UIKit

// MARK: - Instagram Stories

@MainActor
enum InstagramStorySharer {

    enum Result {
        case opened
        /// Instagram isn't installed, or no Facebook App ID is configured.
        /// Callers should fall back to the system share sheet.
        case unavailable
        case failed
    }

    /// Hands `image` to the Instagram story composer as the story background.
    ///
    /// Deliberately does not call `canOpenURL`: that would require an
    /// `LSApplicationQueriesSchemes` entry, and this target has no Info.plist
    /// (`GENERATE_INFOPLIST_FILE = YES`). `open(_:options:)` reports failure just as
    /// well, so we let it try and fall back on `false`.
    static func share(_ image: UIImage) async -> Result {
        guard let url = AppConfig.Sharing.instagramStoriesURL else { return .unavailable }
        guard let data = image.pngData() else { return .failed }

        // Written immediately before opening — Instagram reads the pasteboard on launch.
        UIPasteboard.general.setItems(
            [["com.instagram.sharedSticker.backgroundImage": data]],
            options: [
                .expirationDate: Date().addingTimeInterval(AppConfig.Sharing.pasteboardExpiration)
            ]
        )

        let opened = await UIApplication.shared.open(url, options: [:])
        return opened ? .opened : .unavailable
    }
}

// MARK: - Photo library

@MainActor
enum PhotoSaver {

    enum Result {
        case saved
        case denied
        case failed
    }

    /// Saves `image` to the camera roll, requesting add-only access first.
    static func save(_ image: UIImage) async -> Result {
        let status = await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                continuation.resume(returning: status)
            }
        }

        guard status == .authorized || status == .limited else { return .denied }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
            return .saved
        } catch {
            return .failed
        }
    }
}

// MARK: - System share sheet

/// `UIActivityViewController` wrapper. Used instead of `ShareLink` because the image
/// is rendered on demand when the user taps, rather than being available up front.
struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
