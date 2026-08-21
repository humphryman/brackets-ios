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
        ZStack {
            Text("Detalles de Jugador")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.Colors.primaryText)

            HStack {
                Button { dismiss() } label: {
                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 36, height: 36)
                        .overlay {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
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

    private func teamBadge(_ team: String) -> some View {
        let name = team.trimmingCharacters(in: .whitespaces)

        return VStack(alignment: .trailing, spacing: 6) {
            if let url = teamLogoURL {
                teamLogo(url)
                    .frame(width: 40, height: 40)
            }

            Text(name)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.primaryText.opacity(0.8))
                .lineLimit(1)
                .truncationMode(.tail)
                .multilineTextAlignment(.trailing)
        }
        .frame(maxWidth: 96, alignment: .trailing)
    }

    private func teamLogo(_ url: URL) -> some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFit()
                    .padding(5)
            default:
                Color.clear
            }
        }
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
            infoItem(value: formatDOB(player.dob), label: "Nacimiento")
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
                .foregroundStyle(AppTheme.Colors.secondaryText)
        }
    }

    // MARK: - Total Stats Card

    private func totalStatsCard(_ detail: PlayerSeasonDetailResponse) -> some View {
        let info = detail.playerSeason

        // Order: points first, then remaining active stats
        var orderedKeys: [String] = []
        if info.activeStats.contains("points") {
            orderedKeys.append("points")
        }
        for key in info.activeStats where key != "points" {
            orderedKeys.append(key)
        }

        return VStack(spacing: 16) {
            Text("Stats Totales")
                .font(ShareFont.condensed(.semibold, size: 24))
                .foregroundStyle(AppTheme.Colors.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Stat tiles — horizontal carousel
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(orderedKeys.enumerated()), id: \.offset) { _, key in
                        statBox(
                            value: "\(info.totalStats[key] ?? 0)",
                            label: detail.longNameStats[key] ?? key
                        )
                    }
                }
                .padding(.horizontal, 2)
            }

            // Per-game averages from total_averages: PPG, APG, RPG
            let perGameStats: [(key: String, label: String)] = [
                ("ppg", "PPG"),
                ("apg", "APG"),
                ("rpg", "RPG")
            ]
            let available = perGameStats.compactMap { stat -> (key: String, label: String, value: Double)? in
                guard let value = info.totalAverages[stat.key] else { return nil }
                return (stat.key, stat.label, value)
            }

            if !available.isEmpty {
                HStack(spacing: 0) {
                    ForEach(available, id: \.key) { stat in
                        VStack(spacing: 4) {
                            Text(String(format: "%.1f", stat.value))
                                .font(ShareFont.condensed(.semibold, size: 18))
                                .foregroundStyle(AppTheme.Colors.primaryText)

                            Text(stat.label)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(AppTheme.Colors.secondaryText)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large)
                .fill(Color(white: 0.08))
                .stroke(Color(white: 1.0).opacity(0.12), lineWidth: 1)
        )
    }

    private func statBox(value: String, label: String) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(ShareFont.condensed(.semibold, size: 26))
                .foregroundStyle(AppTheme.Colors.primaryText)

            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 8)
        .frame(width: 84, height: 72)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(AppTheme.Colors.surface)
                .strokeBorder(AppTheme.Colors.outline, lineWidth: 1)
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

        return VStack(spacing: 16) {
            Text(title)
                .font(ShareFont.condensed(.semibold, size: 24))
                .foregroundStyle(AppTheme.Colors.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Table: fixed opponent column | scrollable stats column
            HStack(alignment: .top, spacing: 0) {
                // Fixed opponent column
                VStack(spacing: 0) {
                    // Header
                    Text("Opponent")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(white: 0.5))
                        .frame(height: headerHeight)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)

                    Divider().background(Color(white: 0.2))

                    // Opponent rows
                    ForEach(sortedStats) { game in
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
                            .padding(.horizontal, 12)
                            .opacity(game.played ? 1.0 : 0.5)

                            Divider().background(Color(white: 0.15))
                        }
                    }
                }
                .frame(width: 140)

                // Vertical separator
                Rectangle()
                    .fill(Color(white: 0.2))
                    .frame(width: 1)

                // Stats columns
                let needsScroll = CGFloat(info.activeStats.count) * statColumnWidth > 200
                let statsContent = VStack(spacing: 0) {
                    // Stat headers
                    HStack(spacing: 0) {
                        ForEach(info.activeStats, id: \.self) { key in
                            Text(detail.shortNameStats[key] ?? key.uppercased())
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color(white: 0.5))
                                .frame(minWidth: statColumnWidth, maxWidth: .infinity, alignment: .center)
                        }
                    }
                    .frame(height: headerHeight)

                    Divider().background(Color(white: 0.2))

                    // Stat value rows
                    ForEach(sortedStats) { game in
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

                            Divider().background(Color(white: 0.15))
                        }
                    }
                }

                if needsScroll {
                    ScrollView(.horizontal, showsIndicators: true) {
                        statsContent
                    }
                } else {
                    statsContent
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(white: 0.2), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large)
                .fill(Color(white: 0.08))
                .stroke(Color(white: 1.0).opacity(0.12), lineWidth: 1)
        )
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
