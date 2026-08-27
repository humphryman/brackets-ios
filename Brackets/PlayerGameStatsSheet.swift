//
//  PlayerGameStatsSheet.swift
//  Brackets
//

import SwiftUI

/// Identifiable wrapper so a player-season id can drive `navigationDestination(item:)`.
struct PlayerSeasonRoute: Identifiable, Hashable {
    let id: Int
}

/// Bottom sheet shown when a player is tapped in the "Resultado" stats table.
///
/// Surfaces that player's numbers for this one game — the same columns the table
/// shows — plus the two ways out: share the game stats, or open the full
/// "Perfil del Atleta" screen.
///
/// The layout is deliberately compact: identity sits in a single horizontal row so
/// the stats card and both buttons clear the 60% detent without a swipe.
struct PlayerGameStatsSheet: View {
    let player: PlayerGameStat
    let teamName: String
    let teamLogoURL: String?
    /// Source for the stat columns and their labels, and for the game the share card
    /// puts under the stat line.
    let detail: GameDetailResponse
    /// Footer context on the share cards.
    var tournamentName: String?
    /// Called when the user wants the full player screen; the caller dismisses
    /// the sheet and pushes `PlayerDetailView`.
    let onOpenPlayerDetail: () -> Void

    @State private var isSharePresented = false

    /// Stat keys in the order the results table renders them.
    private var activeStats: [String] { detail.game.activeStats ?? [] }

    /// Side of the square photo. Sized so the identity row costs roughly a fifth of
    /// the detent, leaving room for the stats card and the buttons.
    private let photoSize: CGFloat = 100

    /// Gap between the three sections. Tighter than `Spacing.large` on purpose.
    private let sectionSpacing: CGFloat = 14

    /// Measured width of the stat grid, so a short last row can keep the column
    /// width of the rows above instead of stretching to fill.
    @State private var statGridWidth: CGFloat = 0

    var body: some View {
        ZStack {
            AppTheme.Colors.gray950.ignoresSafeArea()

            ScrollView {
                VStack(spacing: sectionSpacing) {
                    identityRow
                    statsCard
                    actionButtons
                }
                .padding(.horizontal, AppTheme.Layout.screenPadding)
                .padding(.top, AppTheme.Spacing.standard)
                .padding(.bottom, AppTheme.Spacing.standard)
            }
        }
        .sheet(isPresented: $isSharePresented) {
            PlayerStatsShareSheet(
                player: player,
                teamName: teamName,
                detail: detail,
                tournamentName: tournamentName
            )
                .presentationDetents([.large])
                .presentationBackground(AppTheme.Colors.background)
        }
    }

    // MARK: - Identity

    /// Square photo on the left, name stack on the right — the same type treatment
    /// as the hero on "Perfil del Atleta", laid out horizontally.
    private var identityRow: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.medium) {
            playerPhoto
                .frame(width: photoSize, height: photoSize)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large))
                // strokeBorder (not stroke) so the 1pt line stays inside the clip
                .overlay {
                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large)
                        .strokeBorder(AppTheme.Colors.gray700, lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: 0) {
                Text(player.playerFirstName.trimmingCharacters(in: .whitespaces))
                    .font(ShareFont.condensed(.semibold, size: 34))
                    .foregroundStyle(AppTheme.Colors.primaryText)

                Text(player.playerLastName.trimmingCharacters(in: .whitespaces))
                    .font(ShareFont.condensed(.semibold, size: 22))
                    .foregroundStyle(AppTheme.Colors.primaryText.opacity(0.85))

                teamLine
                    .padding(.top, 6)
            }
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// The logo shrinks to a 20pt mark beside the team name rather than getting its
    /// own badge — it keeps the club identity without spending a row of height.
    private var teamLine: some View {
        HStack(spacing: 6) {
            if let logoURL = teamLogoURL, let url = URL(string: logoURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        // Fill, don't fit: many logos ship with an opaque square
                        // background, and only a filled frame clips into a circle.
                        image.resizable().scaledToFill()
                    default:
                        Color.clear
                    }
                }
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.black.opacity(0.45)))
                .clipShape(Circle())
                .overlay { Circle().strokeBorder(Color.white.opacity(0.15), lineWidth: 1) }
            }

            Text(teamName.trimmingCharacters(in: .whitespaces))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.gray400)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    @ViewBuilder
    private var playerPhoto: some View {
        if let imageURL = player.fullImageURL, let url = URL(string: imageURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    playerInitials
                }
            }
        } else {
            playerInitials
        }
    }

    private var playerInitials: some View {
        let initials = String(player.playerFirstName.prefix(1) + player.playerLastName.prefix(1)).uppercased()

        return ZStack {
            AppTheme.Colors.surface
            Text(initials)
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(Color(white: 0.4))
        }
    }

    // MARK: - Stats

    /// Same card as "Stats Totales" on the player screen: titled gray800 panel with a
    /// gray700 outline and a three-per-row grid of unfilled tiles.
    private var statsCard: some View {
        VStack(spacing: AppTheme.Spacing.small) {
            Text("Stats de Juego")
                .font(ShareFont.condensed(.semibold, size: 24))
                .foregroundStyle(AppTheme.Colors.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            statGrid
        }
        .padding(.horizontal, AppTheme.Layout.cardPadding)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large)
                .fill(AppTheme.Colors.gray800)
                .strokeBorder(AppTheme.Colors.gray700, lineWidth: 1)
        )
    }

    /// A short last row keeps the column width of the rows above and centres itself,
    /// so five stats read as 3 + 2 centred and seven as 4 + 3 centred.
    private var statGrid: some View {
        let perRow = statsPerRow
        let spacing: CGFloat = 10
        let rows = stride(from: 0, to: activeStats.count, by: perRow).map {
            Array(activeStats[$0..<min($0 + perRow, activeStats.count)])
        }
        let columnWidth = statGridWidth > 0
            ? (statGridWidth - spacing * CGFloat(perRow - 1)) / CGFloat(perRow)
            : nil

        return VStack(spacing: spacing) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: spacing) {
                    ForEach(row, id: \.self) { statKey in
                        statBox(statKey)
                            .frame(width: columnWidth)
                            .frame(maxWidth: columnWidth == nil ? .infinity : nil)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .background(
            GeometryReader { proxy in
                Color.clear.preference(key: PlayerGameStatGridWidthKey.self, value: proxy.size.width)
            }
        )
        .onPreferenceChange(PlayerGameStatGridWidthKey.self) { statGridWidth = $0 }
    }

    /// Columns per row, per the agreed shape of each count: up to 4 stats stay on one
    /// row; 5 and 6 split into rows of 3; 7 and 8 into rows of 4. Anything larger
    /// keeps 4 so the tiles never get too narrow to read.
    private var statsPerRow: Int {
        let count = activeStats.count
        switch count {
        case ...4: return max(count, 1)
        case 5, 6: return 3
        default:   return 4
        }
    }

    private func statBox(_ statKey: String) -> some View {
        let value = player.dynamicStats[statKey] ?? nil

        return VStack(spacing: 4) {
            Text(value.map { "\($0)" } ?? "-")
                .font(ShareFont.condensed(.semibold, size: 26))
                .foregroundStyle(AppTheme.Colors.primaryText)

            Text(detail.longNameStats[statKey] ?? detail.shortNameStats[statKey] ?? statKey.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.gray400)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 4)
        .frame(height: 60)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Actions

    private var actionButtons: some View {
        VStack(spacing: 10) {
            Button {
                isSharePresented = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .semibold))
                        // The glyph's arrow makes it sit visually low; nudge up to centre it.
                        .offset(y: -1)
                    Text("Compartir Stats de Juego")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(AppTheme.Colors.accentText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small)
                        .fill(AppTheme.Colors.accent)
                )
            }
            .buttonStyle(.plain)

            Button {
                onOpenPlayerDetail()
            } label: {
                Text("Perfil del Atleta")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.primaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small)
                            .fill(Color(red: 40.0 / 255.0, green: 40.0 / 255.0, blue: 40.0 / 255.0))
                            .stroke(Color(white: 1.0).opacity(0.18), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
    }
}

private struct PlayerGameStatGridWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
