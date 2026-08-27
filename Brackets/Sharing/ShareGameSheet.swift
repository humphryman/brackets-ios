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

    var body: some View {
        ZStack {
            AppTheme.Colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                if let model {
                    Spacer(minLength: AppTheme.Layout.sectionSpacing)

                    ShareCardCarousel(styles: ShareCardStyle.allCases, selection: $selectedStyle) { style in
                        ShareCardContainer(style: style, model: model)
                    }

                    // Anchors the action row to the bottom of the sheet, as in the
                    // reference: carousel floats in the space above it.
                    Spacer(minLength: AppTheme.Layout.sectionSpacing)

                    ShareExportSection(render: renderCurrent)
                } else {
                    Spacer()
                    ProgressView()
                        .tint(AppTheme.Colors.accent)
                        .scaleEffect(1.2)
                    Spacer()
                }
            }
        }
        .task {
            model = await ShareCardModel.make(detail: detail, tournamentName: tournamentName, gender: gender)
        }
    }

    // MARK: - Header

    private var header: some View {
        AppTheme.ScreenHeader(title: "Compartir", leadingIcon: "xmark", onLeading: { dismiss() })
            .padding(.horizontal, AppTheme.Layout.screenPadding)
            .padding(.top, AppTheme.Layout.large)
            .padding(.bottom, AppTheme.Layout.itemSpacing)
    }

    // MARK: - Rendering

    private func renderCurrent() -> UIImage? {
        guard let model, let style = selectedStyle else { return nil }
        return ShareImageRenderer.render(style, model: model)
    }
}

// MARK: - Carousel

/// Paged, peeking carousel of card designs.
///
/// Each page renders the live SwiftUI card scaled down rather than a rasterized bitmap —
/// sharper on device, and it avoids rendering images the user never shares.
///
/// Generic over the style so every share surface gets the same paging behaviour; the
/// caller supplies the card for a style and the styles to page through.
struct ShareCardCarousel<Style: Identifiable & Hashable, Card: View>: View {
    let styles: [Style]
    @Binding var selection: Style?
    @ViewBuilder let card: (Style) -> Card

    private static var maxCardWidth: CGFloat { 260 }

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
                            ShareCardThumbnail(width: cardWidth) { card(style) }
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

            // A single design has nothing to page between, so the dots would only be noise.
            if styles.count > 1 {
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
}

/// A card scaled to fit the carousel. Sized by ratio so the layout inside the card is
/// identical to what gets rasterized.
struct ShareCardThumbnail<Content: View>: View {
    let width: CGFloat
    @ViewBuilder let content: () -> Content

    var body: some View {
        let cardSize = AppConfig.Sharing.cardSize
        let scale = width / cardSize.width

        // `scaleEffect` renders about the center without changing the layout box, so the
        // frame must be the scaled size for the two to stay concentric.
        content()
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
