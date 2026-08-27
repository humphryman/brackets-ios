//
//  PlayerDetailView.swift
//  Brackets
//

import SwiftUI

struct PlayerDetailView: View {
    let playerSeasonId: Int
    let tournamentId: Int
    @Environment(\.dismiss) private var dismiss
    @State private var detail: PlayerSeasonDetailResponse?
    @State private var teamLogoURL: URL?
    @State private var statGridWidth: CGFloat = 0
    @State private var showAllStats = false
    @State private var isLoading = true
    @State private var errorMessage: String?

    /// Convenience init from a stat entry (used by StatsLeadersView)
    init(stat: PlayerStatEntry, tournamentId: Int) {
        self.playerSeasonId = stat.playerSeasonId
        self.tournamentId = tournamentId
    }

    init(playerSeasonId: Int, tournamentId: Int) {
        self.playerSeasonId = playerSeasonId
        self.tournamentId = tournamentId
    }

    var body: some View {
        ZStack {
            AppTheme.Colors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                Group {
                    if isLoading {
                        AppTheme.LoadingView(message: "Loading player stats...")
                    } else if let error = errorMessage {
                        AppTheme.ErrorView(message: error) {
                            Task { await loadPlayerSeason() }
                        }
                    } else if let detail = detail {
                        playerContent(detail)
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
        .navigationBarHidden(true)
        .task { await loadPlayerSeason() }
    }

    // MARK: - Header

    private var header: some View {
        AppTheme.ScreenHeader(title: "Perfil del Atleta", onLeading: { dismiss() })
            .padding(.horizontal, AppTheme.Layout.screenPadding)
            .padding(.top, AppTheme.Layout.large)
            .padding(.bottom, AppTheme.Layout.itemSpacing)
    }

    // MARK: - Content

    private func playerContent(_ detail: PlayerSeasonDetailResponse) -> some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.large) {
                heroCard(detail)
                infoCard(detail)
                totalStatsCard(detail)
                if !detail.playerSeason.playoffsStats.isEmpty {
                    opponentStatsCard(detail, stats: detail.playerSeason.playoffsStats, title: "Playoffs")
                }
                if !detail.playerSeason.stats.isEmpty {
                    opponentStatsCard(detail, stats: detail.playerSeason.stats, title: "Stats")
                }
            }
            .padding(.horizontal, AppTheme.Layout.screenPadding)
            .padding(.bottom, AppTheme.Layout.large)
        }
    }

    // MARK: - Hero Card

    /// Full-width square photo with the player name bottom-left and the team
    /// identity bottom-right, both sitting on a dark scrim for contrast.
    private func heroCard(_ detail: PlayerSeasonDetailResponse) -> some View {
        let info = detail.playerSeason

        return Rectangle()
            .fill(AppTheme.Colors.surface)
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .overlay { playerPhoto(info.player) }
            .overlay {
                LinearGradient(
                    colors: [
                        .black.opacity(0.9),
                        .black.opacity(0.45),
                        .clear
                    ],
                    startPoint: .bottom,
                    endPoint: .center
                )
            }
            .overlay(alignment: .bottom) {
                HStack(alignment: .bottom, spacing: 12) {
                    nameBlock(info.player)

                    Spacer(minLength: 12)

                    teamBadge(info.team)
                }
                .padding(16)
            }
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.extraLarge))
            // strokeBorder (not stroke) so the 1pt line stays inside the clip
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.extraLarge)
                    .strokeBorder(AppTheme.Colors.outline, lineWidth: 1)
            }
    }

    private func nameBlock(_ player: Player) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(player.firstName.trimmingCharacters(in: .whitespaces))
                .font(ShareFont.condensed(.semibold, size: 34))
                .foregroundStyle(AppTheme.Colors.primaryText)

            Text(player.lastName.trimmingCharacters(in: .whitespaces))
                .font(ShareFont.condensed(.semibold, size: 22))
                .foregroundStyle(AppTheme.Colors.primaryText.opacity(0.85))
        }
        .lineLimit(1)
        .truncationMode(.tail)
        .layoutPriority(1)
    }

    /// Logo centred over the team name; the pair as a whole hugs the trailing edge.
    private func teamBadge(_ team: String) -> some View {
        let name = team.trimmingCharacters(in: .whitespaces)

        return VStack(spacing: 6) {
            if let url = teamLogoURL {
                teamLogo(url)
            }

            Text(name)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.primaryText.opacity(0.8))
                .lineLimit(1)
                .truncationMode(.tail)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: 96, alignment: .trailing)
    }

    private func teamLogo(_ url: URL) -> some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                // Fill, don't fit: many logos ship with an opaque square background,
                // and only a filled frame gets clipped into an actual circle.
                image
                    .resizable()
                    .scaledToFill()
            default:
                Color.clear
            }
        }
        .frame(width: 40, height: 40)
        .background(Circle().fill(Color.black.opacity(0.45)))
        .clipShape(Circle())
        .overlay {
            Circle().strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
        }
    }

    // MARK: - Info Card

    private func infoCard(_ detail: PlayerSeasonDetailResponse) -> some View {
        let info = detail.playerSeason
        let player = info.player

        return HStack(spacing: 0) {
            infoItem(value: info.number != nil ? "#\(info.number!)" : "-", label: "Número")
            Spacer()
            infoItem(value: formatDOB(player.dob), label: "F. Nacimiento")
            Spacer()
            infoItem(value: player.position?.isEmpty == false ? player.position! : "-", label: "Posición")
            Spacer()
            infoItem(value: info.height?.isEmpty == false ? info.height! : "-", label: "Estatura")
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large)
                .fill(Color(white: 0.08))
                .stroke(Color(white: 1.0).opacity(0.12), lineWidth: 1)
        )
    }

    private func infoItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(AppTheme.Colors.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.Colors.gray400)
        }
    }

    // MARK: - Total Stats Card

    private func totalStatsCard(_ detail: PlayerSeasonDetailResponse) -> some View {
        let cells = statCells(detail)
        // Two full rows fit comfortably; past that the grid turns into a wall of numbers.
        let collapsedLimit = 6
        let isCollapsible = cells.count > collapsedLimit
        let visible = isCollapsible && !showAllStats ? Array(cells.prefix(collapsedLimit)) : cells

        return VStack(spacing: 16) {
            Text("Stats Totales")
                .font(ShareFont.condensed(.semibold, size: 24))
                .foregroundStyle(AppTheme.Colors.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            statGrid(visible)

            if isCollapsible {
                showAllStatsButton(total: cells.count)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large)
                .fill(Color(white: 0.08))
                .stroke(Color(white: 1.0).opacity(0.12), lineWidth: 1)
        )
    }

    /// Per-game averages lead with PPG, then the season totals with points first.
    private func statCells(_ detail: PlayerSeasonDetailResponse) -> [StatCell] {
        let info = detail.playerSeason
        var cells: [StatCell] = []

        for (key, label) in [("ppg", "PPG"), ("apg", "APG"), ("rpg", "RPG")] {
            guard let value = info.totalAverages[key] else { continue }
            cells.append(StatCell(id: key, value: String(format: "%.1f", value), label: label))
        }

        let totalKeys = (info.activeStats.contains("points") ? ["points"] : [])
            + info.activeStats.filter { $0 != "points" }
        for key in totalKeys {
            cells.append(
                StatCell(
                    id: key,
                    value: "\(info.totalStats[key] ?? 0)",
                    label: detail.longNameStats[key] ?? key
                )
            )
        }

        return cells
    }

    /// Three per row, wrapping. A short last row keeps the column width of the rows
    /// above and centres itself, so five stats read as 3 + 2 centred.
    private func statGrid(_ cells: [StatCell]) -> some View {
        let columns = 3
        let spacing: CGFloat = 10
        let rows = stride(from: 0, to: cells.count, by: columns).map {
            Array(cells[$0..<min($0 + columns, cells.count)])
        }
        let columnWidth = statGridWidth > 0
            ? (statGridWidth - spacing * CGFloat(columns - 1)) / CGFloat(columns)
            : nil

        return VStack(spacing: spacing) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: spacing) {
                    ForEach(row) { cell in
                        statBox(value: cell.value, label: cell.label)
                            .frame(width: columnWidth)
                            .frame(maxWidth: columnWidth == nil ? .infinity : nil)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .background(
            GeometryReader { proxy in
                Color.clear.preference(key: StatGridWidthKey.self, value: proxy.size.width)
            }
        )
        .onPreferenceChange(StatGridWidthKey.self) { statGridWidth = $0 }
    }

    /// Same lime link treatment as `VenueLabel`, plus a chevron and the total so the
    /// control reads as "expands in place" rather than "opens somewhere else".
    private func showAllStatsButton(total: Int) -> some View {
        Button {
            withAnimation(AppTheme.Animation.standard) {
                showAllStats.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .rotationEffect(.degrees(showAllStats ? 180 : 0))

                Text(showAllStats ? "Mostrar menos" : "Mostrar todas las stats (\(total))")
                    .font(.system(size: 13))
                    .underline()
            }
            .foregroundStyle(AppTheme.Colors.accent)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func statBox(value: String, label: String) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(ShareFont.condensed(.semibold, size: 26))
                .foregroundStyle(AppTheme.Colors.primaryText)

            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.gray400)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 8)
        .frame(height: 72)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(AppTheme.Colors.surface)
        )
    }

    // MARK: - Stats vs Opponents

    private func opponentStatsCard(_ detail: PlayerSeasonDetailResponse, stats: [PlayerSeasonGameStat], title: String) -> some View {
        let info = detail.playerSeason
        let sortedStats = stats
            .filter { $0.gamePlayed }
            .sorted { $0.played && !$1.played }
        let statColumnWidth: CGFloat = 44
        let headerHeight: CGFloat = 36
        let rowHeight: CGFloat = 52
        // Same inset from the card edge that `StandingsTableBody` uses.
        let cardPadding: CGFloat = 14

        // Matches `GroupStandingsCard`: a gray700 title band over a gray700 column-label
        // band, then gray800 rows — minus the chevron, since these cards never collapse.
        let lastIndex = sortedStats.count - 1

        return VStack(spacing: 0) {
            Text(title)
                .font(AppTheme.Typography.condensed(.semibold, size: 22))
                .foregroundStyle(AppTheme.Colors.primaryText)
                .padding(.horizontal, cardPadding)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(StandingsSurface.header)

            // Table: fixed opponent column | scrollable stats column
            HStack(alignment: .top, spacing: 0) {
                // Fixed opponent column
                VStack(spacing: 0) {
                    // Header
                    Text("Opponent")
                        .font(AppTheme.Typography.tinyCaption)
                        .foregroundStyle(AppTheme.Colors.gray400)
                        .textCase(.uppercase)
                        .frame(height: headerHeight)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, cardPadding)
                        .background(StandingsSurface.header)

                    // Opponent rows
                    ForEach(Array(sortedStats.enumerated()), id: \.element.id) { index, game in
                        VStack(spacing: 0) {
                            HStack(spacing: 8) {
                                opponentCircle(game)
                                    .frame(width: 32, height: 32)

                                Text(game.opponent)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(game.played ? AppTheme.Colors.primaryText : Color(white: 0.3))
                                    .lineLimit(1)
                            }
                            .frame(height: rowHeight)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, cardPadding)
                            .opacity(game.played ? 1.0 : 0.5)

                            if index < lastIndex {
                                Divider().overlay(AppTheme.Colors.separator)
                            }
                        }
                    }
                }
                .frame(width: 140)

                // Vertical separator marking the frozen column
                Rectangle()
                    .fill(AppTheme.Colors.separator)
                    .frame(width: 1)

                // Stats columns
                let minStatsWidth = CGFloat(info.activeStats.count) * statColumnWidth
                let statsContent = VStack(spacing: 0) {
                    // Stat headers
                    HStack(spacing: 0) {
                        ForEach(info.activeStats, id: \.self) { key in
                            Text(detail.shortNameStats[key] ?? key.uppercased())
                                .font(AppTheme.Typography.tinyCaption)
                                .foregroundStyle(AppTheme.Colors.gray400)
                                .textCase(.uppercase)
                                .frame(minWidth: statColumnWidth, maxWidth: .infinity, alignment: .center)
                        }
                    }
                    .frame(height: headerHeight)
                    .background(StandingsSurface.header)

                    // Stat value rows
                    ForEach(Array(sortedStats.enumerated()), id: \.element.id) { index, game in
                        VStack(spacing: 0) {
                            HStack(spacing: 0) {
                                ForEach(info.activeStats, id: \.self) { key in
                                    let value = game.dynamicStats[key].flatMap { $0 }
                                    Text(value != nil ? "\(value!)" : "-")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(game.played ? AppTheme.Colors.primaryText : Color(white: 0.3))
                                        .frame(minWidth: statColumnWidth, maxWidth: .infinity, alignment: .center)
                                }
                            }
                            .frame(height: rowHeight)
                            .opacity(game.played ? 1.0 : 0.5)

                            if index < lastIndex {
                                Divider().overlay(AppTheme.Colors.separator)
                            }
                        }
                    }
                }

                // Sized against the scroll view's own width rather than a fixed
                // threshold: the columns spread across whatever room is left when the
                // stats fit, and only overflow into a scroll when they genuinely
                // outgrow it.
                ScrollView(.horizontal, showsIndicators: true) {
                    statsContent
                        .containerRelativeFrame(.horizontal, alignment: .leading) { width, _ in
                            max(width, minStatsWidth)
                        }
                }
            }
            .background(StandingsSurface.rows)
        }
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large))
    }

    @ViewBuilder
    private func opponentCircle(_ game: PlayerSeasonGameStat) -> some View {
        if let imageURL = game.opponentFullImageURL, let url = URL(string: imageURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .clipShape(Circle())
                default:
                    opponentInitials(game.opponent)
                }
            }
        } else {
            opponentInitials(game.opponent)
        }
    }

    private func opponentInitials(_ name: String) -> some View {
        let initials = String(name.prefix(2)).uppercased()
        return Circle()
            .fill(AppTheme.Colors.accent)
            .overlay(
                Text(initials)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.Colors.accentText)
            )
    }

    // MARK: - Player Photo

    @ViewBuilder
    private func playerPhoto(_ player: Player) -> some View {
        if let picture = player.picture,
           let url = URL(string: picture.hasPrefix("http") ? picture : "\(APIConfig.baseURL)/\(picture)") {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    playerInitialsSurface(player)
                }
            }
        } else {
            playerInitialsSurface(player)
        }
    }

    /// Placeholder that fills the square so the hero layout never shifts between
    /// "no photo", "loading" and "loaded".
    private func playerInitialsSurface(_ player: Player) -> some View {
        let first = player.firstName.trimmingCharacters(in: .whitespaces)
        let last = player.lastName.trimmingCharacters(in: .whitespaces)
        let initials = String(first.prefix(1) + last.prefix(1)).uppercased()

        return AppTheme.Colors.surface
            .overlay {
                Text(initials)
                    .font(ShareFont.condensed(.semibold, size: 96))
                    .foregroundStyle(Color(white: 0.25))
            }
    }

    // MARK: - Helpers

    private func formatDOB(_ dob: String?) -> String {
        guard let dob = dob else { return "-" }

        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd"
        inputFormatter.locale = Locale(identifier: "en_US_POSIX")

        guard let date = inputFormatter.date(from: dob) else { return dob }

        let outputFormatter = DateFormatter()
        outputFormatter.timeZone = AppConfig.DateTime.apiTimeZone
        outputFormatter.dateFormat = "dd MMM yy"
        return outputFormatter.string(from: date)
    }

    // MARK: - Data Loading

    private func loadPlayerSeason() async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await APIService.shared.fetchPlayerSeason(playerSeasonId: playerSeasonId)
            detail = response
            isLoading = false

            // The player_seasons payload has no team logo, so it is resolved from
            // standings afterwards — off the critical path, and silent on failure.
            Task { await loadTeamLogo(teamName: response.playerSeason.team) }
        } catch {
            errorMessage = "Failed to load player stats"
            isLoading = false
            print("❌ Player season loading error: \(error)")
        }
    }

    private func loadTeamLogo(teamName: String) async {
        guard let bundle = try? await APIService.shared.fetchStandings(for: tournamentId) else { return }

        let target = teamName.trimmingCharacters(in: .whitespaces)
        teamLogoURL = flatten(bundle.result)
            .first { $0.teamName.trimmingCharacters(in: .whitespaces).caseInsensitiveCompare(target) == .orderedSame }
            .flatMap { $0.fullImageURL }
            .flatMap { URL(string: $0) }
    }

    private func flatten(_ result: StandingsResult) -> [TeamStanding] {
        switch result {
        case .flat(let standings):
            return standings
        case .groups(let groups):
            return groups.flatMap { $0.standings }
        }
    }
}

// MARK: - Stat Grid Support

/// One value/label pair in the "Stats Totales" grid.
private struct StatCell: Identifiable {
    let id: String
    let value: String
    let label: String
}

/// Carries the grid's available width up so short rows can keep the column width of
/// the full rows above them.
private struct StatGridWidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
