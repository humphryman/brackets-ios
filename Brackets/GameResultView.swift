//
//  GameResultView.swift
//  Brackets
//

import SwiftUI

struct GameResultView: View {
    let game: Game
    let tournamentId: Int
    @Environment(\.dismiss) private var dismiss

    @State private var gameDetail: GameDetailResponse?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedTeamIndex: Int = 0
    @State private var selectedStatIndex: Int = 0

    var body: some View {
        ZStack {
            AppTheme.Colors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                ZStack {
                    Text("Game Result")
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

                if isLoading {
                    Spacer()
                    ProgressView()
                        .tint(AppTheme.Colors.accent)
                        .scaleEffect(1.2)
                    Spacer()
                } else if let errorMessage = errorMessage {
                    Spacer()
                    AppTheme.ErrorView(message: errorMessage) {
                        Task { await loadGameDetail() }
                    }
                    Spacer()
                } else if let detail = gameDetail {
                    ScrollView {
                        VStack(spacing: AppTheme.Spacing.large) {
                            scoreCard(detail: detail)
                            playerStatsCard(detail: detail)
                            gameStatsLeadersCard(detail: detail)
                        }
                        .padding(.horizontal, AppTheme.Layout.screenPadding)
                        .padding(.bottom, AppTheme.Layout.large)
                    }
                } else {
                    Spacer()
                }
            }
        }
        .navigationBarHidden(true)
        .task {
            await loadGameDetail()
        }
    }

    // MARK: - Data Loading

    private func loadGameDetail() async {
        isLoading = true
        errorMessage = nil

        do {
            gameDetail = try await APIService.shared.fetchGameDetail(
                tournamentId: tournamentId,
                gameId: game.id
            )
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    // MARK: - Section 1: Score Card

    @ViewBuilder
    private func scoreCard(detail: GameDetailResponse) -> some View {
        let sets = detail.game.gameSets
        let teams = detail.game.teamStats
        let homeScore = teams.first?.score ?? sets.teamAScore
        let awayScore = teams.count > 1 ? teams[1].score : sets.teamBScore

        VStack(spacing: AppTheme.Spacing.medium) {
            // Date
            if let gameTime = detail.game.gameTime {
                Text(formatDate(gameTime))
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }

            // Teams + Score
            HStack(spacing: 0) {
                // Team A
                VStack(spacing: AppTheme.Spacing.small) {
                    teamLogoCircle(urlString: sets.teamAFullImageURL, name: sets.teamA, size: 56)
                    Text(sets.teamA)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.primaryText)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity)

                // Score box
                VStack(spacing: 4) {
                    HStack(spacing: 8) {
                        Text("\(homeScore)")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(AppTheme.Colors.primaryText)
                        Text("-")
                            .font(.system(size: 18))
                            .foregroundStyle(Color(white: 0.4))
                        Text("\(awayScore)")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(AppTheme.Colors.primaryText)
                    }
                    .fixedSize()
                    .frame(minWidth: 120)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(white: 0.06))
                            .stroke(Color(white: 0.2), lineWidth: 1)
                    )

                    Text("Final")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(white: 0.4))
                }

                // Team B
                VStack(spacing: AppTheme.Spacing.small) {
                    teamLogoCircle(urlString: sets.teamBFullImageURL, name: sets.teamB, size: 56)
                    Text(sets.teamB)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.primaryText)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity)
            }

            // Venue
            if let venue = detail.game.venue {
                Text(venue.name + (venue.courtNumber.map { " - \($0)" } ?? ""))
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }
        }
        .padding(AppTheme.Layout.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large)
                .fill(Color(white: 0.1))
                .stroke(Color(white: 1.0).opacity(0.18), lineWidth: 1)
        )
    }

    // MARK: - Section 2: Player Stats

    @ViewBuilder
    private func playerStatsCard(detail: GameDetailResponse) -> some View {
        let teams = detail.game.teamStats
        let activeStats = detail.game.activeStats

        if teams.count >= 2 {
            let safeIndex = min(selectedTeamIndex, teams.count - 1)
            let selectedTeam = teams[safeIndex]
            let players = selectedTeam.playerStats.filter { !$0.isTeamEntry }

            VStack(spacing: AppTheme.Spacing.large) {
                // Title
                Text("Player Stats")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppTheme.Colors.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Team selector
                HStack(spacing: 0) {
                    ForEach(Array(teams.enumerated()), id: \.element.id) { index, team in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedTeamIndex = index
                            }
                        } label: {
                            Text(team.teamName)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(selectedTeamIndex == index ? AppTheme.Colors.accentText : Color(white: 0.5))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    Capsule()
                                        .fill(selectedTeamIndex == index ? AppTheme.Colors.accent : Color.clear)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3)
                .background(
                    Capsule()
                        .fill(Color(white: 0.18))
                )

                // Stats table: fixed player column + scrollable stats
                let rowHeight: CGFloat = 50
                let headerHeight: CGFloat = 38

                HStack(spacing: 0) {
                    // Fixed player name column
                    VStack(spacing: 0) {
                        Text("PLAYER")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color(white: 0.45))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(height: headerHeight)
                            .padding(.leading, 12)

                        Divider().background(Color(white: 0.2))

                        ForEach(Array(players.enumerated()), id: \.element.id) { index, player in
                            HStack(spacing: 8) {
                                playerAvatarCircle(player: player, size: 30)
                                Text(player.playerName)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(AppTheme.Colors.primaryText)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(height: rowHeight)
                            .padding(.leading, 12)
                            .background(index % 2 == 0 ? Color(white: 0.14) : Color.clear)
                        }
                    }
                    .frame(width: 150)

                    // Single scrollable stats area (header + all rows scroll together)
                    ScrollView(.horizontal, showsIndicators: true) {
                        VStack(spacing: 0) {
                            // Stat headers
                            HStack(spacing: 0) {
                                ForEach(activeStats, id: \.self) { statKey in
                                    Text(detail.shortNameStats[statKey] ?? statKey.uppercased())
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(Color(white: 0.45))
                                        .frame(width: 56)
                                }
                            }
                            .frame(height: headerHeight)

                            Divider().background(Color(white: 0.2))

                            // Stat value rows
                            ForEach(Array(players.enumerated()), id: \.element.id) { index, player in
                                HStack(spacing: 0) {
                                    ForEach(activeStats, id: \.self) { statKey in
                                        let value = player.dynamicStats[statKey] ?? nil
                                        Text(value.map { "\($0)" } ?? "-")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(AppTheme.Colors.primaryText)
                                            .frame(width: 56)
                                    }
                                }
                                .frame(height: rowHeight)
                                .background(index % 2 == 0 ? Color(white: 0.14) : Color.clear)
                            }
                        }
                    }
                }
            }
            .padding(AppTheme.Layout.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large)
                    .fill(Color(white: 0.1))
                    .stroke(Color(white: 1.0).opacity(0.18), lineWidth: 1)
            )
        }
    }

    // MARK: - Section 3: Game Stats Leaders

    @ViewBuilder
    private func gameStatsLeadersCard(detail: GameDetailResponse) -> some View {
        let activeStats = detail.game.activeStats

        if !activeStats.isEmpty {
            let safeStatIndex = min(selectedStatIndex, activeStats.count - 1)
            let currentStatKey = activeStats[safeStatIndex]
            let statLabel = detail.shortNameStats[currentStatKey] ?? currentStatKey.uppercased()
            let longLabel = detail.longNameStats[currentStatKey] ?? currentStatKey.capitalized
            let leaders = rankedPlayers(for: currentStatKey, detail: detail)

            VStack(spacing: AppTheme.Spacing.large) {
                // Title
                Text("Game Stats Leaders")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppTheme.Colors.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Category selector with arrows
                HStack {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedStatIndex = (selectedStatIndex - 1 + activeStats.count) % activeStats.count
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppTheme.Colors.primaryText)
                            .frame(width: 36, height: 36)
                            .background(Circle().stroke(Color(white: 0.25), lineWidth: 1))
                    }

                    Spacer()

                    VStack(spacing: 2) {
                        Text(longLabel)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(AppTheme.Colors.accent)
                        Text("GAME LEADERS")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color(white: 0.45))
                    }

                    Spacer()

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedStatIndex = (selectedStatIndex + 1) % activeStats.count
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppTheme.Colors.primaryText)
                            .frame(width: 36, height: 36)
                            .background(Circle().stroke(Color(white: 0.25), lineWidth: 1))
                    }
                }
                .padding(.horizontal, 4)

                Divider().background(Color(white: 0.2))

                // Leaders content or empty state
                if leaders.isEmpty {
                    Text("No info for this stat.")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppTheme.Spacing.huge)
                } else {
                    // #1 Leader - hero layout
                    if let top = leaders.first {
                        HStack(alignment: .center, spacing: 12) {
                            // Player image
                            playerHeroImage(player: top.player, size: 120)

                            // Name
                            VStack(alignment: .leading, spacing: 2) {
                                Text(top.player.playerFirstName)
                                    .font(.system(size: 16))
                                    .foregroundStyle(AppTheme.Colors.primaryText)
                                Text(top.player.playerLastName)
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundStyle(AppTheme.Colors.primaryText)
                            }

                            Spacer(minLength: 0)

                            // Stat circle with value + short name
                            VStack(spacing: 2) {
                                Text("\(top.value)")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(AppTheme.Colors.accentText)
                                Text(statLabel)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(AppTheme.Colors.accentText)
                            }
                            .frame(width: 52, height: 52)
                            .background(
                                Circle()
                                    .fill(AppTheme.Colors.accent)
                            )
                        }
                    }

                    // #2-4 runners up
                    let runnersUp = Array(leaders.dropFirst().prefix(3))
                    ForEach(Array(runnersUp.enumerated()), id: \.element.player.id) { _, entry in
                        HStack(spacing: 12) {
                            playerAvatarCircle(player: entry.player, size: 44)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.player.playerFirstName)
                                    .font(.system(size: 12))
                                    .foregroundStyle(AppTheme.Colors.secondaryText)
                                Text(entry.player.playerLastName)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(AppTheme.Colors.primaryText)
                            }

                            Spacer()

                            HStack(spacing: 6) {
                                Text(statLabel)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Color(white: 0.4))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule()
                                            .fill(Color(white: 0.18))
                                    )
                                Text("\(entry.value)")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(AppTheme.Colors.accent)
                            }
                        }
                    }
                }

                // Page indicator dots
                HStack(spacing: 6) {
                    ForEach(Array(activeStats.enumerated()), id: \.element) { index, _ in
                        Capsule()
                            .fill(index == safeStatIndex ? AppTheme.Colors.accent : Color(white: 0.25))
                            .frame(width: index == safeStatIndex ? 20 : 8, height: 6)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(AppTheme.Layout.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large)
                    .fill(Color(white: 0.1))
                    .stroke(Color(white: 1.0).opacity(0.18), lineWidth: 1)
            )
            .gesture(
                DragGesture(minimumDistance: 30, coordinateSpace: .local)
                    .onEnded { value in
                        let horizontal = value.translation.width
                        if horizontal < -30 {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedStatIndex = (selectedStatIndex + 1) % activeStats.count
                            }
                        } else if horizontal > 30 {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedStatIndex = (selectedStatIndex - 1 + activeStats.count) % activeStats.count
                            }
                        }
                    }
            )
        }
    }

    // MARK: - Helpers

    private struct RankedPlayer {
        let player: PlayerGameStat
        let value: Int
    }

    private func rankedPlayers(for statKey: String, detail: GameDetailResponse) -> [RankedPlayer] {
        let allPlayers = detail.game.teamStats.flatMap { $0.playerStats }
            .filter { !$0.isTeamEntry }

        let ranked = allPlayers.compactMap { player -> RankedPlayer? in
            guard let val = player.dynamicStats[statKey] ?? nil, val > 0 else { return nil }
            return RankedPlayer(player: player, value: val)
        }
        .sorted { $0.value > $1.value }

        return ranked
    }

    @ViewBuilder
    private func teamLogoCircle(urlString: String?, name: String, size: CGFloat) -> some View {
        if let urlString = urlString, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color(white: 0.25), lineWidth: 1))
                default:
                    initialsCircle(name: name, size: size)
                }
            }
        } else {
            initialsCircle(name: name, size: size)
        }
    }

    @ViewBuilder
    private func initialsCircle(name: String, size: CGFloat) -> some View {
        Circle()
            .fill(Color(white: 0.15))
            .frame(width: size, height: size)
            .overlay(
                Text(getInitials(name))
                    .font(.system(size: size * 0.3, weight: .bold))
                    .foregroundStyle(AppTheme.Colors.primaryText)
            )
            .overlay(Circle().stroke(Color(white: 0.25), lineWidth: 1))
    }

    @ViewBuilder
    private func playerAvatarCircle(player: PlayerGameStat, size: CGFloat) -> some View {
        if let imageURL = player.fullImageURL, let url = URL(string: imageURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                default:
                    initialsCircle(name: player.playerName, size: size)
                }
            }
        } else {
            initialsCircle(name: player.playerName, size: size)
        }
    }

    @ViewBuilder
    private func playerHeroImage(player: PlayerGameStat, size: CGFloat) -> some View {
        if let imageURL = player.fullImageURL, let url = URL(string: imageURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium))
                default:
                    heroInitialsRect(name: player.playerName, size: size)
                }
            }
        } else {
            heroInitialsRect(name: player.playerName, size: size)
        }
    }

    @ViewBuilder
    private func heroInitialsRect(name: String, size: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
            .fill(Color(white: 0.18))
            .frame(width: size, height: size)
            .overlay(
                Text(getInitials(name))
                    .font(.system(size: size * 0.25, weight: .bold))
                    .foregroundStyle(Color(white: 0.4))
            )
    }

    private func getInitials(_ name: String) -> String {
        let words = name.split(separator: " ")
        if words.count >= 2 {
            return String(words[0].prefix(1) + words[1].prefix(1)).uppercased()
        } else if let first = words.first {
            return String(first.prefix(3)).uppercased()
        }
        return "?"
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM dd, yyyy"
        return formatter.string(from: date)
    }
}
