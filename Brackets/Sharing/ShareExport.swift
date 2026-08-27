//
//  ShareExport.swift
//  Brackets
//

import SwiftUI
import UIKit

/// Identifiable box so the activity sheet can be driven by `.sheet(item:)`.
struct ShareableImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

/// The action half of a share sheet: the three destinations, the toast they raise, and
/// the system activity sheet.
///
/// Every share surface embeds this below its own preview area, so the destinations
/// behave identically no matter what is being shared. The image is rasterized on tap
/// via `render` rather than up front — the user may never share at all.
struct ShareExportSection: View {
    let render: () -> UIImage?

    @State private var isPreparing = false
    @State private var activityImage: ShareableImage?
    @State private var toast: String?

    var body: some View {
        ShareDestinationRow(
            onInstagram: { await shareToInstagram() },
            onSave: { await saveToPhotos() },
            onMore: { await presentActivitySheet() }
        )
        .disabled(isPreparing)
        .opacity(isPreparing ? 0.5 : 1)
        .overlay(alignment: .bottom) {
            if let toast {
                toastView(toast)
            }
        }
        .sheet(item: $activityImage) { shareable in
            ActivityView(items: [shareable.image])
        }
    }

    // MARK: - Actions

    private func shareToInstagram() async {
        isPreparing = true
        defer { isPreparing = false }

        guard let image = render() else {
            showToast("No se pudo generar la imagen")
            return
        }

        switch await InstagramStorySharer.share(image) {
        case .opened:
            break
        case .unavailable:
            // No Instagram, or no Facebook App ID configured yet — the system share
            // sheet still gets the user there, just with an extra tap.
            activityImage = ShareableImage(image: image)
        case .failed:
            showToast("No se pudo compartir")
        }
    }

    private func saveToPhotos() async {
        isPreparing = true
        defer { isPreparing = false }

        guard let image = render() else {
            showToast("No se pudo generar la imagen")
            return
        }

        switch await PhotoSaver.save(image) {
        case .saved:  showToast("Guardado en Fotos")
        case .denied: showToast("Permite el acceso a Fotos en Ajustes")
        case .failed: showToast("No se pudo guardar")
        }
    }

    private func presentActivitySheet() async {
        isPreparing = true
        defer { isPreparing = false }

        guard let image = render() else {
            showToast("No se pudo generar la imagen")
            return
        }
        activityImage = ShareableImage(image: image)
    }

    // MARK: - Toast

    private func showToast(_ message: String) {
        toast = message
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            if toast == message { toast = nil }
        }
    }

    private func toastView(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(AppTheme.Colors.primaryText)
            .padding(.horizontal, AppTheme.Spacing.standard)
            .padding(.vertical, AppTheme.Spacing.medium)
            .background(
                Capsule().fill(Color(white: 0.18))
            )
            .padding(.bottom, 110)
            .transition(.opacity)
            .animation(AppTheme.Animation.quick, value: toast)
    }
}
