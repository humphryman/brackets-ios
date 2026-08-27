//
//  PlayerPortraitShareCard.swift
//  Brackets
//
//  The athlete share card, built in the game cards' visual language: the textured
//  backdrop, the inset panel and the shared footer from `ShareCardViews`. Same
//  constraints apply — no `Material`, no `AsyncImage`, `ShareFont` for numerals.
//
//  It inverts the game cards' hierarchy on purpose: the athlete and their stat line
//  carry the composition, and the scoreline is a footnote.
//

import SwiftUI
import UIKit

/// Frame for the athlete card.
///
/// The game cards reserve a 76pt right-hand gutter for their rotated gender label.
/// This one carries no edge labels, so the panel is inset symmetrically and the extra
/// ~58pt goes to the content column — 256pt here against the game cards' 198pt.
private enum AthleteCardGeometry {
    static let panelHorizontal: CGFloat = 22
    static let panelVertical: CGFloat = 40

    /// Padding between the panel's edge and its contents.
    static let contentInset: CGFloat = 26

    static let panelCornerRadius: CGFloat = 20

    static var contentHorizontal: CGFloat { panelHorizontal + contentInset }
}

/// The `ScoreboardShareCard` composition with the athlete in place of the matchup:
/// portrait, name, a labelled rule, then the stat line. The game is one quiet strip
/// at the bottom.
struct PlayerPortraitShareCard: View {
    let model: PlayerStatsShareModel

    /// Rows the two-column stat grid needs. Everything above it scales to this: the
    /// content column is 422pt tall, and only two rows fit the full-size composition.
    /// Three or four rows must step down or the card renders taller than the story
    /// canvas — `ShareImageRenderer` asserts on exactly that.
    private var statRows: Int {
        max(1, Int((Double(model.stats.count) / 2).rounded(.up)))
    }

    /// Picks a value for the current row count: 1–2 rows full size, 3 medium, 4+ compact.
    private func metric(full: CGFloat, medium: CGFloat, compact: CGFloat) -> CGFloat {
        if statRows >= 4 { return compact }
        if statRows == 3 { return medium }
        return full
    }

    private var portraitSize: CGFloat { metric(full: 124, medium: 108, compact: 92) }
    private var portraitCornerRadius: CGFloat { metric(full: 20, medium: 18, compact: 16) }
    private var firstNameSize: CGFloat { metric(full: 42, medium: 38, compact: 32) }
    private var lastNameSize: CGFloat { metric(full: 24, medium: 22, compact: 20) }
    private var namePadding: CGFloat { metric(full: 12, medium: 10, compact: 8) }
    private var statValueSize: CGFloat { metric(full: 36, medium: 34, compact: 28) }
    private var statLabelSize: CGFloat { metric(full: 9, medium: 9, compact: 8) }
    private var gridRowSpacing: CGFloat { metric(full: 8, medium: 7, compact: 6) }
    private var blockSpacing: CGFloat { metric(full: 16, medium: 13, compact: 11) }

    /// The date's treatment, applied to every footer line.
    private static let footerFont: Font = .system(size: 10, weight: .medium)

    /// Steps the name block walks down until it fits the content column.
    ///
    /// Per-`Text` `minimumScaleFactor` cannot be used here: a long given name
    /// ("AQUILES ANHUAR") scales to its floor while a surname that happens to fit stays
    /// at full size, which inverts the hierarchy the card is built on. Scaling both
    /// lines by the same factor preserves the ratio at every step.
    private static let nameScales: [CGFloat] = [1.0, 0.86, 0.74, 0.63, 0.54]

    var body: some View {
        ZStack {
            ShareCardBackdrop(style: .dark)

            // Inset panel — the backdrop bleeds around it. Rounded, unlike the game
            // cards' square panel, so it reads as a card rather than a crop.
            RoundedRectangle(cornerRadius: AthleteCardGeometry.panelCornerRadius)
                .fill(Color.black.opacity(0.45))
                .padding(.horizontal, AthleteCardGeometry.panelHorizontal)
                .padding(.vertical, AthleteCardGeometry.panelVertical)

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                portrait

                nameBlock
                    .padding(.top, namePadding)

                Text(model.teamName.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .kerning(1.2)
                    .foregroundStyle(AppTheme.Colors.accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.top, 4)

                RuleLabel(
                    text: "Stats de Juego",
                    fill: AppTheme.Colors.sky900,
                    textColor: .white,
                    ruleColor: AppTheme.Colors.sky900
                )
                .padding(.top, blockSpacing)

                statGrid
                    .padding(.top, blockSpacing)

                scoreStrip
                    .padding(.top, blockSpacing)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, AthleteCardGeometry.contentHorizontal)
            .padding(.top, AthleteCardGeometry.panelVertical + 24)
            .padding(.bottom, AthleteCardGeometry.panelVertical + 74)

            ShareCardFooter(
                title: model.tournamentName,
                subtitle: model.date.map { ShareCardFormat.date($0) },
                detail: model.venueName,
                tint: .white,
                leadingInset: AthleteCardGeometry.panelHorizontal + 16,
                trailingInset: AthleteCardGeometry.panelHorizontal + 16,
                bottomInset: AthleteCardGeometry.panelVertical + 18,
                // One flat type scale across tournament, date and venue: the athlete
                // and their stat line carry the card, so the footer should not compete.
                titleFont: Self.footerFont,
                subtitleFont: Self.footerFont,
                detailFont: Self.footerFont
            )
        }
        // Pins the export to the story canvas. `ImageRenderer.proposedSize` only
        // proposes: without this the ZStack grows to whatever the content demands and
        // the render comes out taller than 1080 × 1920.
        .frame(width: AppConfig.Sharing.cardSize.width,
               height: AppConfig.Sharing.cardSize.height)
        .clipped()
    }

    /// Given name over surname, both scaled by the same factor so the given name is
    /// always the larger of the two. `ViewThatFits` picks the first step that fits.
    private var nameBlock: some View {
        ViewThatFits(in: .horizontal) {
            ForEach(Self.nameScales, id: \.self) { scale in
                names(scale: scale)
            }
        }
    }

    private func names(scale: CGFloat) -> some View {
        VStack(spacing: 0) {
            Text(model.firstName.uppercased())
                .font(ShareFont.condensed(.bold, size: firstNameSize * scale))
                .foregroundStyle(.white)

            Text(model.lastName.uppercased())
                .font(ShareFont.condensed(.semibold, size: lastNameSize * scale))
                .foregroundStyle(.white.opacity(0.8))
                // Barlow Condensed carries a lot of built-in leading, so the pair needs
                // pulling together — but only to -2: any tighter and a tilde on the
                // surname ("PEÑA") collides with the line above.
                .padding(.top, -2)
        }
        .lineLimit(1)
        // Report the untruncated width, so `ViewThatFits` rejects a step that would
        // otherwise silently truncate instead of moving on to the next one.
        .fixedSize(horizontal: true, vertical: false)
    }

    private var portrait: some View {
        Group {
            if let photo = model.photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
            } else {
                // Same fallback the app uses in its player rows: the two initials in
                // gray400 on gray800, rather than a photo-shaped placeholder.
                ZStack {
                    AppTheme.Colors.gray800
                    Text(model.initials)
                        .font(ShareFont.condensed(.bold, size: portraitSize * 0.37))
                        .foregroundStyle(AppTheme.Colors.gray400)
                }
            }
        }
        .frame(width: portraitSize, height: portraitSize)
        .clipShape(RoundedRectangle(cornerRadius: portraitCornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: portraitCornerRadius)
                .strokeBorder(AppTheme.Colors.lime400, lineWidth: 3)
        }
    }

    /// Two columns. The content column is wide enough for three, but paired numerals
    /// keep each stat legible at a glance in a story feed.
    private var statGrid: some View {
        let rows = stride(from: 0, to: model.stats.count, by: 2).map {
            Array(model.stats[$0..<min($0 + 2, model.stats.count)])
        }

        return VStack(spacing: gridRowSpacing) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 10) {
                    ForEach(row) { cell in
                        HStack(alignment: .firstTextBaseline, spacing: 5) {
                            Text(cell.value)
                                .font(ShareFont.condensed(.bold, size: statValueSize))
                                .foregroundStyle(.white)

                            Text(cell.label.uppercased())
                                .font(.system(size: statLabelSize, weight: .bold))
                                .kerning(0.4)
                                .foregroundStyle(.white.opacity(0.55))
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // Keep a lone trailing cell in its own column instead of centring it.
                    if row.count < 2 {
                        Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
                    }
                }
            }
        }
    }

    /// The game, deliberately reduced to small type under a hairline: a crest and club
    /// name either side of the score.
    private var scoreStrip: some View {
        VStack(spacing: 6) {
            Rectangle()
                .fill(.white.opacity(0.18))
                .frame(height: 1)

            HStack(alignment: .top, spacing: 10) {
                teamColumn(name: model.teamAName, logo: model.teamALogo)

                HStack(spacing: 6) {
                    Text(model.teamAScore.map(String.init) ?? "-")
                        .foregroundStyle(model.teamAWon ? AppTheme.Colors.accent : .white.opacity(0.6))

                    Text("-")
                        .font(ShareFont.condensed(.semibold, size: 18))
                        .foregroundStyle(.white.opacity(0.35))

                    Text(model.teamBScore.map(String.init) ?? "-")
                        .foregroundStyle(model.teamBWon ? AppTheme.Colors.accent : .white.opacity(0.6))
                }
                .font(ShareFont.condensed(.bold, size: 26))
                .fixedSize()
                // Keeps the score optically level with the crests rather than with the
                // top of the club names beneath them.
                .padding(.top, 1)

                teamColumn(name: model.teamBName, logo: model.teamBLogo)
            }
        }
    }

    /// Crest over club name. Each column takes an equal share of what the score leaves,
    /// so two long club names can crowd their own column but never each other.
    private func teamColumn(name: String, logo: UIImage?) -> some View {
        VStack(spacing: 4) {
            ShareTeamLogo(image: logo, name: name, size: 22)

            Text(name.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                // A lower floor lets SwiftUI shrink the name onto a single line and
                // truncate it ("DEPORTIVO GUADALUPE VIC…") instead of wrapping. Keeping
                // the floor high forces the second line to be used first.
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }
}
