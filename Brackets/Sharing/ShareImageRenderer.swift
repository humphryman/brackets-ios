//
//  ShareImageRenderer.swift
//  Brackets
//

import SwiftUI
import UIKit

/// Rasterizes a share card design to a story-sized `UIImage`.
@MainActor
enum ShareImageRenderer {

    /// Renders `style` at 1080 × 1920 px (360 × 640 pt @ 3x).
    ///
    /// Every image on `model` must already be a `UIImage` — see `ShareImageLoader`.
    static func render(_ style: ShareCardStyle, model: ShareCardModel) -> UIImage? {
        render(ShareCardContainer(style: style, model: model))
    }

    /// Renders any card-sized view at 1080 × 1920 px.
    ///
    /// `content` is expected to already be framed at `AppConfig.Sharing.cardSize`;
    /// `proposedSize` only proposes, so a view that sizes itself differently will
    /// export off-canvas and trip the debug assertion below.
    static func render(_ content: some View) -> UIImage? {
        let size = AppConfig.Sharing.cardSize

        let renderer = ImageRenderer(content: content)
        renderer.scale = AppConfig.Sharing.renderScale
        renderer.isOpaque = true
        renderer.proposedSize = ProposedViewSize(size)

        guard let image = renderer.uiImage else { return nil }

        #if DEBUG
        let expected = CGSize(
            width: size.width * AppConfig.Sharing.renderScale,
            height: size.height * AppConfig.Sharing.renderScale
        )
        let actual = CGSize(
            width: image.size.width * image.scale,
            height: image.size.height * image.scale
        )
        assert(
            abs(actual.width - expected.width) < 1 && abs(actual.height - expected.height) < 1,
            "Share image is \(actual) but Instagram stories expect \(expected)"
        )
        #endif

        return image
    }
}
