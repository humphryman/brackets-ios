//
//  UpcomingGameView.swift
//  Brackets
//
//  Created by Humberto on 16/02/26.
//

import SwiftUI

struct UpcomingGameView: View {
    let game: Game
    let tournamentId: Int
    @Environment(\.dismiss) private var dismiss

    @State private var gameDetail: GameDetailResponse?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedTeamIndex: Int = 0

    var body: some View {
        ZStack {
            AppTheme.Colors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                ZStack {
                    Text("Upcoming Game")
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
                            teamMatchupCard(detail: detail)
                            keyStatsCard(detail: detail)
                            rosterCard(detail: detail)
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

    // MARK: - Section 1: Team Matchup

    @ViewBuilder
    private func teamMatchupCard(detail: GameDetailResponse) -> some View {
        let sets = detail.game.gameSets

        VStack(spacing: AppTheme.Spacing.large) {
            // Team logos side by side
            HStack(spacing: AppTheme.Spacing.large) {
                // Team A
                VStack(spacing: AppTheme.Spacing.small) {
                    teamLogoCircle(urlString: sets.teamAFullImageURL, name: sets.teamA, size: 72)

                    Text(sets.teamA)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.primaryText)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity)

                // VS
                VStack(spacing: 4) {
                    if let gameTime = detail.game.gameTime {
                        Text(formatTime(gameTime))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(AppTheme.Colors.accent)
                    }

                    Text("VS")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color(white: 0.5))
                }

                // Team B
                VStack(spacing: AppTheme.Spacing.small) {
                    teamLogoCircle(urlString: sets.teamBFullImageURL, name: sets.teamB, size: 72)

                    Text(sets.teamB)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.primaryText)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity)
            }

            // Recent form + record per team
            HStack(spacing: 0) {
                teamFormColumn(lastFive: detail.game.teamStats.first { $0.id == sets.teamAId }?.lastFiveGames)
                    .frame(maxWidth: .infinity)
                teamFormColumn(lastFive: detail.game.teamStats.first { $0.id == sets.teamBId }?.lastFiveGames)
                    .frame(maxWidth: .infinity)
            }

            // Venue info
            if let venue = detail.game.venue {
                HStack(spacing: 6) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.Colors.accent)
                    Text(venue.name + (venue.courtNumber.map { " - Court \($0)" } ?? ""))
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.Colors.secondaryText)
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

    // MARK: - Section 2: Key Stats

    @ViewBuilder
    private func keyStatsCard(detail: GameDetailResponse) -> some View {
        let sets = detail.game.gameSets
        let activeStats = detail.game.activeStats

        VStack(spacing: 0) {
            // Title
            Text("Key Stats")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppTheme.Colors.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AppTheme.Layout.cardPadding)
                .padding(.top, AppTheme.Layout.cardPadding)
                .padding(.bottom, AppTheme.Spacing.medium)

            // Team name headers
            HStack {
                HStack(spacing: 6) {
                    teamLogoCircle(urlString: sets.teamAFullImageURL, name: sets.teamA, size: 24)
                    Text(sets.teamA)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.primaryText)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()

                HStack(spacing: 6) {
                    Text(sets.teamB)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.primaryText)
                        .lineLimit(1)
                    teamLogoCircle(urlString: sets.teamBFullImageURL, name: sets.teamB, size: 24)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, AppTheme.Layout.cardPadding)
            .padding(.bottom, AppTheme.Spacing.medium)

            // Stat comparison rows with alternating backgrounds
            ForEach(Array(activeStats.enumerated()), id: \.element) { index, statKey in
                let label = detail.shortNameStats[statKey] ?? statKey.uppercased()
                let teamA = detail.game.teamStats.first { $0.id == sets.teamAId }
                let teamB = detail.game.teamStats.first { $0.id == sets.teamBId }
                let leftVal = teamA?.totalTeamStats?[statKey] ?? 0
                let rightVal = teamB?.totalTeamStats?[statKey] ?? 0

                statComparisonRow(label: label, leftValue: leftVal, rightValue: rightVal)
                    .padding(.horizontal, AppTheme.Layout.cardPadding)
                    .padding(.vertical, 8)
                    .background(index % 2 == 0 ? Color(white: 0.14) : Color.clear)
            }

            Spacer().frame(height: AppTheme.Spacing.small)
        }
        .background(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large)
                .fill(Color(white: 0.1))
                .stroke(Color(white: 1.0).opacity(0.18), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large))
    }

    private let statBarHeight: CGFloat = 30
    private let statBarTeamAColor = Color(red: 0.12, green: 0.14, blue: 0.35)
    private let statBarTeamBColor = AppTheme.Colors.accent
    private let statBarLoserColor = Color(white: 0.22)

    @ViewBuilder
    private func statComparisonRow(label: String, leftValue: Double, rightValue: Double) -> some View {
        let maxVal = max(leftValue, rightValue, 1)
        let leftWins = leftValue > rightValue
        let rightWins = rightValue > leftValue

        HStack(spacing: 6) {
            // Left bar (Team A)
            GeometryReader { geo in
                let minBarWidth: CGFloat = 50
                let fraction = leftValue / maxVal
                let barWidth = max(minBarWidth, geo.size.width * fraction)
                let barColor = leftWins ? statBarTeamAColor : statBarLoserColor

                HStack {
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(barColor)
                            .frame(width: barWidth, height: statBarHeight)

                        Text(String(format: "%.1f", leftValue))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(AppTheme.Colors.primaryText)
                            .padding(.leading, 10)
                    }
                    Spacer(minLength: 0)
                }
            }
            .frame(height: statBarHeight)

            // Center label
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(white: 0.5))
                .frame(width: 44)
                .multilineTextAlignment(.center)

            // Right bar (Team B)
            GeometryReader { geo in
                let minBarWidth: CGFloat = 50
                let fraction = rightValue / maxVal
                let barWidth = max(minBarWidth, geo.size.width * fraction)
                let barColor = rightWins ? statBarTeamBColor : statBarLoserColor

                HStack {
                    Spacer(minLength: 0)
                    ZStack(alignment: .trailing) {
                        Capsule()
                            .fill(barColor)
                            .frame(width: barWidth, height: statBarHeight)

                        Text(String(format: "%.1f", rightValue))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(rightWins ? AppTheme.Colors.accentText : AppTheme.Colors.primaryText)
                            .padding(.trailing, 10)
                    }
                }
            }
            .frame(height: statBarHeight)
        }
    }

    // MARK: - Section 3: Roster

    @ViewBuilder
    private func rosterCard(detail: GameDetailResponse) -> some View {
        let teams = detail.game.teamStats

        if teams.count >= 2 {
            let safeIndex = min(selectedTeamIndex, teams.count - 1)
            let selectedTeam = teams[safeIndex]
            let players = selectedTeam.playerStats.filter { !$0.isTeamEntry }

            VStack(spacing: AppTheme.Spacing.large) {
                Text("Roster")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppTheme.Colors.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Segmented team tab selector
                HStack(spacing: 0) {
                    ForEach(Array(teams.enumerated()), id: \.element.id) { index, team in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedTeamIndex = index
                            }
                        } label: {
                            Text(team.teamName.uppercased())
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

                // Player grid
                let columns = [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10)
                ]

                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(players) { player in
                        playerCard(player: player)
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

    @ViewBuilder
    private func playerCard(player: PlayerGameStat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Player photo (square, rounded corners)
            if let imageURL = player.fullImageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .aspectRatio(1, contentMode: .fill)
                            .clipped()
                    default:
                        playerInitialsRect(name: player.playerName)
                    }
                }
            } else {
                playerInitialsRect(name: player.playerName)
            }

            // Name + Number row
            HStack(alignment: .top, spacing: 4) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(player.playerFirstName)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AppTheme.Colors.primaryText)
                        .lineLimit(1)
                    Text(player.playerLastName)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AppTheme.Colors.primaryText)
                        .lineLimit(1)
                    // Position placeholder
                    Text(positionLabel(for: player))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                if let number = player.playerNumber, number > 0 {
                    Text("\(number)")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(AppTheme.Colors.primaryText)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 6)
        }
        .background(Color(white: 0.15))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium))
    }

    @ViewBuilder
    private func playerInitialsRect(name: String) -> some View {
        Rectangle()
            .fill(Color(white: 0.22))
            .aspectRatio(1, contentMode: .fill)
            .overlay(
                Text(getInitials(name))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Color(white: 0.45))
            )
    }

    private func positionLabel(for player: PlayerGameStat) -> String {
        // Use dynamic stats keys presence as a rough proxy; real position data
        // would come from the API. For now, show gender or a dash.
        if let gender = player.playerGender {
            return gender == "male" ? "Player" : "Player"
        }
        return ""
    }

    // MARK: - Helpers

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
                        .overlay(
                            Circle()
                                .stroke(Color(white: 0.25), lineWidth: 1)
                        )
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
            .overlay(
                Circle()
                    .stroke(Color(white: 0.25), lineWidth: 1)
            )
    }

    @ViewBuilder
    private func playerInitialsCircle(name: String, size: CGFloat) -> some View {
        Circle()
            .fill(Color(white: 0.2))
            .frame(width: size, height: size)
            .overlay(
                Text(getInitials(name))
                    .font(.system(size: size * 0.3, weight: .bold))
                    .foregroundStyle(AppTheme.Colors.primaryText)
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

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    // MARK: - Mocked Data Helpers

    /// Combined form dots + win/loss record column for one team
    @ViewBuilder
    private func teamFormColumn(lastFive: [Int?]?) -> some View {
        let games = lastFive ?? []
        let wins = games.compactMap { $0 }.filter { $0 == 1 }.count
        let losses = games.compactMap { $0 }.filter { $0 == 0 }.count

        VStack(spacing: 6) {
            // W/L circles with letter inside
            HStack(spacing: 5) {
                ForEach(Array(games.enumerated()), id: \.offset) { _, result in
                    ZStack {
                        Circle()
                            .fill(result == 1 ? AppTheme.Colors.accent : result == 0 ? Color(red: 0.8, green: 0.2, blue: 0.2) : Color(white: 0.15))
                            .frame(width: 22, height: 22)

                        Text(result == 1 ? "W" : result == 0 ? "L" : "-")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(result == 1 ? AppTheme.Colors.accentText : result == 0 ? .white : Color(white: 0.4))
                    }
                }
            }

            // Record number
            Text("\(wins)/\(losses)")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppTheme.Colors.primaryText)

            // Label
            Text("WIN / LOSS")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color(white: 0.4))
        }
    }

}
