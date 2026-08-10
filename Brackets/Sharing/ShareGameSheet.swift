//
//  ShareGameSheet.swift
//  Brackets
//

import SwiftUI

// MARK: - Entry point

/// Share icon for the game screens' hand-rolled headers, styled to match the
/// circular back button next to it. Owns the sheet presentation.
struct ShareGameButton: View {
    let detail: GameDetailResponse
    var tournamentName: String?
    var gender: Gender?

    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.primaryText)
                        // Nudge up: the glyph's arrow makes it sit visually low in the circle.
                        .offset(y: -1)
                }
        }
        .sheet(isPresented: $isPresented) {
            ShareGameSheet(detail: detail, tournamentName: tournamentName, gender: gender)
                .presentationDetents([.large])
                .presentationBackground(AppTheme.Colors.background)
        }
    }
}

/// Share overlay for a game: swipe between card designs, then pick a destination.
struct ShareGameSheet: View {
    let detail: GameDetailResponse
    var tournamentName: String?
    var gender: Gender?

    @Environment(\.dismiss) private var dismiss

    @State private var model: ShareCardModel?
    @State private var selectedStyle: ShareCardStyle? = ShareCardStyle.allCases.first
    @State private var isPreparing = false
    @State private var activityImage: ShareableImage?
    @State private var toast: String?

    var body: some View {
        ZStack {
            AppTheme.Colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                if let model {
                    Spacer(minLength: AppTheme.Layout.sectionSpacing)

                    ShareCardCarousel(model: model, selection: $selectedStyle)

                    // Anchors the action row to the bottom of the sheet, as in the
                    // reference: carousel floats in the space above it.
                    Spacer(minLength: AppTheme.Layout.sectionSpacing)

                    ShareDestinationRow(
                        onInstagram: { await shareToInstagram() },
                        onSave: { await saveToPhotos() },
                        onMore: { await presentActivitySheet() }
                    )
                    .disabled(isPreparing)
                    .opacity(isPreparing ? 0.5 : 1)
                } else {
                    Spacer()
                    ProgressView()
                        .tint(AppTheme.Colors.accent)
                        .scaleEffect(1.2)
                    Spacer()
                }
            }

            if let toast {
                toastView(toast)
            }
        }
        .task {
            model = await ShareCardModel.make(detail: detail, tournamentName: tournamentName, gender: gender)
        }
        .sheet(item: $activityImage) { shareable in
            ActivityView(items: [shareable.image])
        }
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            Text("Compartir")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.Colors.primaryText)

            HStack {
                Button {
                    dismiss()
                } label: {
                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 36, height: 36)
                        .overlay {
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(AppTheme.Colors.primaryText)
                        }
                }
                Spacer()
            }
        }
        .padding(.horizontal, AppTheme.Layout.screenPadding)
        .padding(.top, AppTheme.Layout.large)
        .padding(.bottom, AppTheme.Layout.itemSpacing)
    }

    // MARK: - Actions

    private func renderCurrent() -> UIImage? {
        guard let model, let style = selectedStyle else { return nil }
        return ShareImageRenderer.render(style, model: model)
    }

    private func shareToInstagram() async {
        isPreparing = true
        defer { isPreparing = false }

        guard let image = renderCurrent() else {
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

        guard let image = renderCurrent() else {
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

        guard let image = renderCurrent() else {
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
        VStack {
            Spacer()
            Text(message)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.primaryText)
                .padding(.horizontal, AppTheme.Spacing.standard)
                .padding(.vertical, AppTheme.Spacing.medium)
                .background(
                    Capsule().fill(Color(white: 0.18))
                )
                .padding(.bottom, 110)
        }
        .transition(.opacity)
        .animation(AppTheme.Animation.quick, value: toast)
    }
}

// MARK: - Carousel

/// Paged, peeking carousel of the available card designs.
///
/// Each page renders the live SwiftUI card scaled down rather than a rasterized bitmap —
/// sharper on device, and it avoids rendering images the user never shares.
struct ShareCardCarousel: View {
    let model: ShareCardModel
    @Binding var selection: ShareCardStyle?

    private let styles = ShareCardStyle.allCases

    private static let maxCardWidth: CGFloat = 260

    /// 9:16, from the card design size.
    private static var aspect: CGFloat {
        AppConfig.Sharing.cardSize.height / AppConfig.Sharing.cardSize.width
    }

    var body: some View {
        VStack(spacing: AppTheme.Spacing.standard) {
            GeometryReader { geometry in
                let cardWidth = min(geometry.size.width * 0.66, Self.maxCardWidth)
                let sidePadding = max((geometry.size.width - cardWidth) / 2, 0)

                // `viewAligned` + symmetric side padding is what produces the neighbour
                // peek; `TabView(.page)` would force full-width pages instead.
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppTheme.Spacing.standard) {
                        ForEach(styles) { style in
                            ShareCardThumbnail(style: style, model: model, width: cardWidth)
                                .id(style)
                        }
                    }
                    .scrollTargetLayout()
                    .padding(.horizontal, sidePadding)
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $selection, anchor: .center)
                .frame(height: cardWidth * Self.aspect)
                .frame(maxHeight: .infinity, alignment: .center)
            }
            // GeometryReader is greedy: without this it swallows every spare point in the
            // sheet and strands the page dots at the bottom of the screen.
            .frame(height: Self.maxCardWidth * Self.aspect)

            HStack(spacing: 7) {
                ForEach(styles) { style in
                    Circle()
                        .fill(style == selection ? AppTheme.Colors.accent : Color(white: 0.3))
                        .frame(width: 7, height: 7)
                }
            }
            .animation(AppTheme.Animation.quick, value: selection)
        }
    }
}

/// A card scaled to fit the carousel. Sized by ratio so the layout inside the card is
/// identical to what gets rasterized.
struct ShareCardThumbnail: View {
    let style: ShareCardStyle
    let model: ShareCardModel
    let width: CGFloat

    var body: some View {
        let cardSize = AppConfig.Sharing.cardSize
        let scale = width / cardSize.width

        // `scaleEffect` renders about the center without changing the layout box, so the
        // frame must be the scaled size for the two to stay concentric.
        ShareCardContainer(style: style, model: model)
            .scaleEffect(scale)
            .frame(width: cardSize.width * scale, height: cardSize.height * scale)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
    }
}

// MARK: - Destinations

/// The "Compartir en" action row.
struct ShareDestinationRow: View {
    let onInstagram: () async -> Void
    let onSave: () async -> Void
    let onMore: () async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.standard) {
            Text("Compartir en")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(AppTheme.Colors.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(alignment: .top, spacing: AppTheme.Spacing.large) {
                button(title: "Instagram\nStory", systemImage: "camera.circle.fill", isPrimary: true, action: onInstagram)
                button(title: "Guardar", systemImage: "arrow.down.to.line", action: onSave)
                button(title: "Más", systemImage: "square.and.arrow.up", action: onMore)
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, AppTheme.Layout.screenPadding)
        .padding(.bottom, AppTheme.Layout.extraLarge)
    }

    private func button(
        title: String,
        systemImage: String,
        isPrimary: Bool = false,
        action: @escaping () async -> Void
    ) -> some View {
        Button {
            Task { await action() }
        } label: {
            VStack(spacing: 8) {
                Circle()
                    .fill(isPrimary ? AnyShapeStyle(AppTheme.Colors.accent)
                                    : AnyShapeStyle(Color(white: 0.16)))
                    .frame(width: 58, height: 58)
                    .overlay {
                        Image(systemName: systemImage)
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(isPrimary ? AppTheme.Colors.accentText
                                                       : AppTheme.Colors.primaryText)
                    }

                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(width: 74)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Supporting types

/// Identifiable box so the activity sheet can be driven by `.sheet(item:)`.
private struct ShareableImage: Identifiable {
    let id = UUID()
    let image: UIImage
}
