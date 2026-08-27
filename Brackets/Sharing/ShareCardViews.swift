//
//  ShareCardViews.swift
//  Brackets
//
//  Share card designs. Every card is laid out at `AppConfig.Sharing.cardSize`
//  (360 × 640 pt) and rasterized at 3x to Instagram's 1080 × 1920 story canvas.
//
//  Three constraints apply to everything in this file:
//    1. No `Material` / `.ultraThinMaterial` — `ImageRenderer` does not rasterize
//       them and they export as transparent holes. Gradients and opacity only.
//    2. No `AsyncImage` — images arrive pre-resolved on `ShareCardModel`.
//    3. Big numerals use Barlow Condensed via `ShareFont`, never the system font.
//

import SwiftUI

// MARK: - Geometry

/// One source of truth for the card's frame. The panel, its contents, the footer and the
/// rotated edge labels all derive from these, so the right-hand gutter is guaranteed to
/// stay clear of the panel and nothing can drift out of frame.
enum CardGeometry {
    static let panelLeading: CGFloat = 26
    /// Wide enough to leave a clean gutter for the oversized vertical label.
    static let panelTrailing: CGFloat = 76
    static let panelTop: CGFloat = 46
    static let panelBottom: CGFloat = 46

    /// Padding between the panel's edge and its contents.
    static let contentInset: CGFloat = 30

    static var contentLeading: CGFloat { panelLeading + contentInset }
    static var contentTrailing: CGFloat { panelTrailing + contentInset }

    /// Post-rotation footprint of the big right-hand label.
    static let gutterWidth: CGFloat = 80
    /// Pre-rotation length budget — rotation does not change the layout box, so the text
    /// must be bounded here or a long stage like "CUARTOS DE FINAL" runs off the card.
    static let edgeLabelLength: CGFloat = 540
    static let kickerLength: CGFloat = 300
}

// MARK: - Container

/// Routes a style to its design. The single place that knows the full set of cards.
struct ShareCardContainer: View {
    let style: ShareCardStyle
    let model: ShareCardModel

    var body: some View {
        Group {
            switch style {
            case .scoreboard: ScoreboardShareCard(model: model)
            case .spotlight:  SpotlightShareCard(model: model)
            }
        }
        .frame(width: AppConfig.Sharing.cardSize.width,
               height: AppConfig.Sharing.cardSize.height)
        // Safety net: a child that over-demands width would otherwise expand the card
        // and shift the whole composition off-centre in the exported image.
        .clipped()
    }
}

// MARK: - Design 1: Scoreboard (dark colorway, stacked)

/// The reference composition: team crest, huge score, a labelled rule across the middle,
/// second score, second crest — framed by rotated edge labels.
struct ScoreboardShareCard: View {
    let model: ShareCardModel

    var body: some View {
        ZStack {
            ShareCardBackdrop(style: .dark)

            // Inset panel, as in the references — the backdrop bleeds around it.
            Rectangle()
                .fill(Color.black.opacity(0.45))
                .padding(.leading, CardGeometry.panelLeading)
                .padding(.trailing, CardGeometry.panelTrailing)
                .padding(.vertical, CardGeometry.panelTop)

            ShareCardEdgeLabels(kicker: model.kickerLabel, edgeLabel: model.edgeLabel, tint: AppTheme.Colors.accent, kickerTint: .white)

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                if model.isUpcoming {
                    upcomingStack
                } else {
                    ShareTeamLogo(image: model.teamALogo, name: model.teamAName, size: 76)
                    scoreName(model.teamAName, isWinner: model.isWinner(.a))
                        .padding(.top, 3)
                    numeral(model.teamAScore, isWinner: model.isWinner(.a))
                    RuleLabel(text: "Score Final", fill: AppTheme.Colors.accent, textColor: .black, ruleColor: AppTheme.Colors.accent)
                        .padding(.vertical, 2)
                    numeral(model.teamBScore, isWinner: model.isWinner(.b))
                    scoreName(model.teamBName, isWinner: model.isWinner(.b))
                        .padding(.bottom, 3)
                    ShareTeamLogo(image: model.teamBLogo, name: model.teamBName, size: 76)
                }

                Spacer(minLength: 0)
            }
            .padding(.leading, CardGeometry.contentLeading)
            .padding(.trailing, CardGeometry.contentTrailing)
            .padding(.top, CardGeometry.panelTop + 24)
            .padding(.bottom, CardGeometry.panelBottom + 74)

            ShareCardFooter.game(model, tint: .white)
        }
    }

    /// Score numerals sit tight to the rule; the winner stays pure white and the loser
    /// drops back rather than changing size, so the pair still reads as one block.
    private func numeral(_ value: Int?, isWinner: Bool) -> some View {
        Text(value.map(String.init) ?? "-")
            .font(ShareFont.score(size: 122))
            .foregroundStyle(isWinner ? .white : Color.white.opacity(0.55))
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            // Barlow Condensed carries a lot of built-in leading; pull the numerals in
            // so they nearly touch the rule, as in the reference.
            .padding(.vertical, -14)
    }

    /// Small team name sitting between the crest and its score. Matches the score's
    /// colour so each team's name, score and win/loss state read as one unit.
    private func scoreName(_ name: String, isWinner: Bool) -> some View {
        Text(name.uppercased())
            .font(ShareFont.condensed(.semibold, size: 18))
            .foregroundStyle(isWinner ? .white : Color.white.opacity(0.55))
            .multilineTextAlignment(.center)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Symmetric matchup: each team's crest sits directly with its own name, the date rule
    /// separates them, and the kickoff time closes the block. Previously the time sat
    /// between team A's crest and the names, so neither team read as owning its own row.
    private var upcomingStack: some View {
        VStack(spacing: 12) {
            ShareTeamLogo(image: model.teamALogo, name: model.teamAName, size: 88)
            teamName(model.teamAName)

            RuleLabel(
                text: model.date.map { ShareCardFormat.compact($0) } ?? "Próximamente",
                fill: AppTheme.Colors.accent,
                textColor: .black,
                ruleColor: AppTheme.Colors.accent
            )
            .padding(.vertical, 2)

            teamName(model.teamBName)
            ShareTeamLogo(image: model.teamBLogo, name: model.teamBName, size: 88)

            if let date = model.date {
                // Deliberately restrained: the matchup is the headline here, not the clock.
                Text(ShareCardFormat.time(date))
                    .font(ShareFont.condensed(.bold, size: 46))
                    .foregroundStyle(AppTheme.Colors.accent)
                    .lineLimit(1)
                    .padding(.top, 6)
            }
        }
    }

    private func teamName(_ name: String) -> some View {
        Text(name.uppercased())
            .font(ShareFont.condensed(.semibold, size: 32))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.5)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Design 2: Spotlight (lime colorway, editorial)

/// Left-aligned and typographic: each team's name set large in condensed caps with its
/// score beside it. No athlete portrait — the panel and type carry the card.
struct SpotlightShareCard: View {
    let model: ShareCardModel

    var body: some View {
        ZStack {
            ShareCardBackdrop(style: .lime)

            Rectangle()
                .fill(AppTheme.Colors.accent)
                .padding(.leading, CardGeometry.panelLeading)
                .padding(.trailing, CardGeometry.panelTrailing)
                .padding(.vertical, CardGeometry.panelTop)

            ShareCardEdgeLabels(kicker: model.kickerLabel, edgeLabel: model.edgeLabel, tint: AppTheme.Colors.accent, kickerTint: .black)

            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 0)

                if model.isUpcoming {
                    upcomingBody
                } else {
                    resultBody
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, CardGeometry.contentLeading)
            .padding(.trailing, CardGeometry.contentTrailing)
            .padding(.top, CardGeometry.panelTop + 24)
            .padding(.bottom, CardGeometry.panelBottom + 74)

            ShareCardFooter.game(model, tint: .black)
        }
    }

    private var resultBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            teamBlock(
                name: model.teamAName,
                logo: model.teamALogo,
                score: model.teamAScore,
                isWinner: model.isWinner(.a)
            )

            Rectangle()
                .fill(Color.black.opacity(0.55))
                .frame(height: 3)
                .padding(.vertical, 12)

            teamBlock(
                name: model.teamBName,
                logo: model.teamBLogo,
                score: model.teamBScore,
                isWinner: model.isWinner(.b)
            )

            RuleLabel(text: "Score Final", fill: .black, textColor: .white, ruleColor: .black)
                .padding(.top, 26)
        }
    }

    /// Name over score, with the crest tucked beside the name — the score is the anchor,
    /// so it gets the largest optical size on the card.
    private func teamBlock(name: String, logo: UIImage?, score: Int?, isWinner: Bool) -> some View {
        // Loser drops to a muted olive (#3F6212) instead of dimmed black, so it reads
        // as recessed against the lime panel while staying legible.
        let ink = isWinner ? Color.black : Color(red: 0.247, green: 0.384, blue: 0.071)

        return VStack(alignment: .leading, spacing: -10) {
            HStack(spacing: 10) {
                ShareTeamLogo(image: logo, name: name, size: 34, plateColor: .black.opacity(0.08))

                Text(name.uppercased())
                    .font(ShareFont.condensed(.semibold, size: 30))
                    .foregroundStyle(ink)
                    // Two lines: real club names ("Deportivo Guadalupe Victoria") are far
                    // too long for a single 198pt line and would truncate mid-word.
                    .lineLimit(2)
                    .minimumScaleFactor(0.5)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(score.map(String.init) ?? "-")
                .font(ShareFont.score(size: 132))
                .foregroundStyle(ink)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.vertical, -18)
        }
    }

    /// Unplayed games have no score to anchor on, so the team names take the big
    /// condensed treatment instead.
    private var upcomingBody: some View {
        VStack(alignment: .leading, spacing: -8) {
            bigName(model.teamAName)

            Text("vs")
                .font(ShareFont.condensed(.semibold, size: 34))
                .foregroundStyle(.black.opacity(0.55))
                .padding(.vertical, 6)

            bigName(model.teamBName)

            if let date = model.date {
                RuleLabel(
                    text: "\(ShareCardFormat.compact(date))  ·  \(ShareCardFormat.time(date))",
                    fill: .black,
                    textColor: .white,
                    ruleColor: .black
                )
                .padding(.top, 28)
            }
        }
    }

    private func bigName(_ name: String) -> some View {
        Text(name.uppercased())
            .font(ShareFont.condensed(.bold, size: 74))
            .foregroundStyle(.black)
            .lineLimit(2)
            .minimumScaleFactor(0.45)
            .lineSpacing(-14)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Shared pieces

/// A label centred on a horizontal rule — the "SCORE FINAL" device from the references.
struct RuleLabel: View {
    let text: String
    let fill: Color
    let textColor: Color
    let ruleColor: Color

    var body: some View {
        // The rule sits *behind* the label rather than flanking it in an HStack. As
        // siblings the flexible rules competed with the text for width and the label
        // only ever got a third of the row, truncating to "SCOR…". Layered, the text is
        // offered the full width and shrinks only when it genuinely does not fit.
        ZStack {
            Rectangle()
                .fill(ruleColor)
                .frame(height: 4)

            Text(text.uppercased())
                .font(.system(size: 17, weight: .heavy))
                .foregroundStyle(textColor)
                .kerning(0.5)
                .lineLimit(1)
                .minimumScaleFactor(0.45)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(fill)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Rotated labels down both edges: a small kicker on the left, the oversized gender or
/// stage on the right.
struct ShareCardEdgeLabels: View {
    /// Small rotated label inside the panel's left edge.
    let kicker: String
    /// Oversized rotated label in the right-hand gutter. Nothing is drawn when nil.
    let edgeLabel: String?
    let tint: Color
    let kickerTint: Color

    var body: some View {
        ZStack {
            // Kicker, inside the panel along its left edge.
            HStack {
                Text(kicker.uppercased())
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(kickerTint.opacity(0.7))
                    .kerning(1.6)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(width: CardGeometry.kickerLength)
                    .rotationEffect(.degrees(-90))
                    // Rotation leaves the layout box unchanged, so the text is bounded
                    // before rotating (length) and after (footprint).
                    .frame(width: 18)
                    .padding(.leading, CardGeometry.panelLeading + 8)

                Spacer(minLength: 0)
            }

            // Oversized gender/stage, in the gutter to the right of the panel.
            if let edgeLabel {
                HStack(spacing: 0) {
                    Spacer(minLength: 0)

                    Text(edgeLabel.uppercased())
                        .font(ShareFont.condensed(.extraBold, size: 76))
                        .foregroundStyle(tint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.35)
                        .frame(width: CardGeometry.edgeLabelLength)
                        .rotationEffect(.degrees(-90))
                        .frame(width: CardGeometry.gutterWidth)
                }
            }
        }
    }
}

/// Procedural ground. Layered gradients plus a generated diagonal grain stand in for the
/// gritty sports photograph in the references; swap `textureImageName` for a real asset
/// and it is used instead, no other change required.
struct ShareCardBackdrop: View {
    enum Style { case dark, lime }

    let style: Style

    /// Set to an Assets.xcassets image name to replace the procedural texture.
    static let textureImageName: String? = nil

    var body: some View {
        ZStack {
            Color.black

            if let name = Self.textureImageName, let texture = UIImage(named: name) {
                Image(uiImage: texture)
                    .resizable()
                    .scaledToFill()
                    .frame(width: AppConfig.Sharing.cardSize.width,
                           height: AppConfig.Sharing.cardSize.height)
                    .clipped()
                    .overlay(tintOverlay)
            } else {
                proceduralTexture
                    .overlay(tintOverlay)
            }
        }
        .frame(width: AppConfig.Sharing.cardSize.width,
               height: AppConfig.Sharing.cardSize.height)
        .clipped()
    }

    private var tintOverlay: some View {
        LinearGradient(
            colors: style == .dark
                ? [AppTheme.Colors.accent.opacity(0.30), .black.opacity(0.55), .black]
                : [AppTheme.Colors.accent.opacity(0.16), .black.opacity(0.75), .black],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Diagonal banding at varying opacity — reads as crumpled/creased texture once the
    /// tint sits on top, and costs no asset.
    private var proceduralTexture: some View {
        ZStack {
            LinearGradient(
                colors: [Color(white: 0.22), Color(white: 0.05), Color(white: 0.16)],
                startPoint: .top,
                endPoint: .bottom
            )

            Canvas { context, size in
                let bandCount = 26
                let step = size.height / CGFloat(bandCount)
                for index in 0..<bandCount {
                    // Deterministic pseudo-random so the texture is stable across renders.
                    let seed = Double((index &* 2654435761) % 1000) / 1000.0
                    let y = CGFloat(index) * step
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y + CGFloat(seed) * step))
                    path.addLine(to: CGPoint(x: size.width, y: y - CGFloat(seed) * step * 0.6))
                    path.addLine(to: CGPoint(x: size.width, y: y + step))
                    path.addLine(to: CGPoint(x: 0, y: y + step * 1.2))
                    path.closeSubpath()
                    context.fill(path, with: .color(.white.opacity(0.015 + seed * 0.03)))
                }
            }

            RadialGradient(
                colors: [.white.opacity(0.10), .clear],
                center: UnitPoint(x: 0.3, y: 0.15),
                startRadius: 0,
                endRadius: 420
            )
        }
    }
}

/// Tournament name, date and venue along the bottom edge.
/// Brackets mark over the site wordmark, pinned bottom-right on every card.
struct ShareBrandMark: View {
    let tint: Color

    var body: some View {
        VStack(spacing: 4) {
            // The asset is a lime mark on an opaque black square, so it reads as a badge
            // on the dark card and as a deliberate black tile on the lime one.
            Image("AppLogo")
                .resizable()
                .scaledToFill()
                .frame(width: 30, height: 30)
                .clipShape(Circle())

            Text(AppConfig.Sharing.websiteLabel)
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(tint.opacity(0.75))
                .lineLimit(1)
                .fixedSize()
        }
        // Shift the whole mark right; the logo stays centred over the handle.
        .offset(x: 12)
    }
}

struct ShareCardFooter: View {
    /// Heaviest line — the tournament on the game cards.
    let title: String?
    /// Middle line, typically the date.
    let subtitle: String?
    /// Lightest line, typically the venue.
    let detail: String?
    let tint: Color
    /// Insets from the card edge. Default to the game cards' panel, which reserves a
    /// wide right-hand gutter; cards without one pass their own.
    var leadingInset: CGFloat = CardGeometry.panelLeading + 16
    var trailingInset: CGFloat = CardGeometry.panelTrailing + 16
    var bottomInset: CGFloat = CardGeometry.panelBottom + 18
    /// Type for the three lines. Defaults to the game cards' stepped scale; a card that
    /// wants a flatter footer passes the same font for all three.
    var titleFont: Font = .system(size: 12, weight: .heavy)
    var subtitleFont: Font = .system(size: 10, weight: .medium)
    var detailFont: Font = .system(size: 9, weight: .regular)

    var body: some View {
        VStack {
            Spacer()

            HStack(alignment: .bottom, spacing: 10) {
                // Date and venue are separate rows rather than one joined line: sharing
                // the width with the brand block leaves too little for both on one line.
                VStack(alignment: .leading, spacing: 2) {
                    if let title, !title.isEmpty {
                        Text(title.uppercased())
                            .font(titleFont)
                            .foregroundStyle(tint)
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                    }

                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(subtitleFont)
                            .foregroundStyle(tint.opacity(0.7))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }

                    if let detail, !detail.isEmpty {
                        Text(detail)
                            .font(detailFont)
                            .foregroundStyle(tint.opacity(0.55))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                ShareBrandMark(tint: tint)
            }
            // Sits inside the panel: on the lime card the ink is black, so it would be
            // invisible if it dropped onto the dark ground below the panel. Uses the
            // panel's own insets, not the narrower content column.
            .padding(.leading, leadingInset)
            .padding(.trailing, trailingInset)
            .padding(.bottom, bottomInset)
        }
    }
}

extension ShareCardFooter {
    /// The game cards' footer: tournament, date, venue.
    static func game(_ model: ShareCardModel, tint: Color) -> ShareCardFooter {
        ShareCardFooter(
            title: model.tournamentName,
            subtitle: model.date.map { ShareCardFormat.date($0) },
            detail: model.venueName,
            tint: tint
        )
    }
}

/// Circular team logo with an initials fallback, driven by a pre-resolved `UIImage`.
/// The light backing plate keeps dark and transparent logos legible on any ground.
struct ShareTeamLogo: View {
    let image: UIImage?
    let name: String
    let size: CGFloat
    var isWinner: Bool = false
    var plateColor: Color = .white

    var body: some View {
        Group {
            if let image {
                Circle()
                    .fill(plateColor)
                    .overlay(
                        // `scaledToFill`, not `scaledToFit`: club logos are square images
                        // with their own background, so fitting them left visible plate
                        // showing through as white arcs in the circle's corners. Filling
                        // crops the square's corners instead, which the artwork tolerates.
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    )
            } else {
                Circle()
                    .fill(plateColor)
                    .overlay(
                        Text(ShareCardFormat.initials(name))
                            .font(ShareFont.condensed(.bold, size: size * 0.42))
                            .foregroundStyle(.black.opacity(0.75))
                    )
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle().stroke(AppTheme.Colors.accent, lineWidth: isWinner ? 3 : 0)
        )
    }
}
