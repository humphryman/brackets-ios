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
                HStack(alignment: .center, spacing: 12) {
                    Button {
                        dismiss()
                    } label: {
                        Circle()
                            .fill(AppTheme.Colors.cardBackground)
                            .frame(width: 40, height: 40)
                            .overlay {
                                Image(systemName: "arrow.left")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(AppTheme.Colors.primaryText)
                            }
                    }

                    Text("Upcoming Game")
                        .font(AppTheme.Typography.largeTitle)
                        .foregroundStyle(AppTheme.Colors.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Spacer()
                }
                .padding(.horizontal, AppTheme.Layout.extraLarge)
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
                    Text("VS")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color(white: 0.5))

                    if let gameTime = detail.game.gameTime {
                        Text(formatTime(gameTime))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(AppTheme.Colors.accent)
                    }
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

            // Recent form dots (mocked)
            HStack(spacing: AppTheme.Spacing.large) {
                formDotsView(teamId: sets.teamAId)
                    .frame(maxWidth: .infinity)
                Spacer().frame(width: 50)
                formDotsView(teamId: sets.teamBId)
                    .frame(maxWidth: .infinity)
            }

            // Win/Loss record (mocked)
            HStack(spacing: AppTheme.Spacing.large) {
                let recordA = mockedRecord(teamId: sets.teamAId)
                let recordB = mockedRecord(teamId: sets.teamBId)

                Text("\(recordA.wins)W - \(recordA.losses)L")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .frame(maxWidth: .infinity)

                Text("WIN / LOSS")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(white: 0.4))
                    .frame(width: 80)

                Text("\(recordB.wins)W - \(recordB.losses)L")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.secondaryText)
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
            VStack(spacing: 4) {
                Text("Key Stats")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppTheme.Colors.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Tournament averages per game")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
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
                let (leftVal, rightVal) = mockedStatValues(statKey: statKey, teamAId: sets.teamAId, teamBId: sets.teamBId)

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
    private let statBarNavyColor = Color(red: 0.12, green: 0.14, blue: 0.30)

    @ViewBuilder
    private func statComparisonRow(label: String, leftValue: Int, rightValue: Int) -> some View {
        let maxVal = max(leftValue, rightValue, 1)
        let leftIsHigher = leftValue >= rightValue
        let rightIsHigher = rightValue >= leftValue

        HStack(spacing: 6) {
            // Left bar (grows from left)
            GeometryReader { geo in
                let minBarWidth: CGFloat = 50
                let fraction = CGFloat(leftValue) / CGFloat(maxVal)
                let barWidth = max(minBarWidth, geo.size.width * fraction)

                HStack {
                    // Bar with value inside
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(leftIsHigher ? AppTheme.Colors.accent : statBarNavyColor)
                            .frame(width: barWidth, height: statBarHeight)

                        Text(String(format: "%.1f", Double(leftValue)))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(leftIsHigher ? AppTheme.Colors.accentText : AppTheme.Colors.primaryText)
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

            // Right bar (grows from right)
            GeometryReader { geo in
                let minBarWidth: CGFloat = 50
                let fraction = CGFloat(rightValue) / CGFloat(maxVal)
                let barWidth = max(minBarWidth, geo.size.width * fraction)

                HStack {
                    Spacer(minLength: 0)
                    // Bar with value inside
                    ZStack(alignment: .trailing) {
                        Capsule()
                            .fill(rightIsHigher ? AppTheme.Colors.accent : statBarNavyColor)
                            .frame(width: barWidth, height: statBarHeight)

                        Text(String(format: "%.1f", Double(rightValue)))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(rightIsHigher ? AppTheme.Colors.accentText : AppTheme.Colors.primaryText)
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

    /// Deterministic form dots based on team ID
    private func formDotsView(teamId: Int) -> some View {
        let pattern = mockedFormPattern(teamId: teamId)
        return HStack(spacing: 4) {
            ForEach(Array(pattern.enumerated()), id: \.offset) { _, isWin in
                Circle()
                    .fill(isWin ? AppTheme.Colors.accent : Color(red: 0.8, green: 0.2, blue: 0.2))
                    .frame(width: 10, height: 10)
            }
        }
    }

    /// Returns a deterministic W/L pattern (5 games) based on team ID
    private func mockedFormPattern(teamId: Int) -> [Bool] {
        let seed = teamId % 6
        let patterns: [[Bool]] = [
            [true, true, false, true, true],
            [true, false, true, true, false],
            [false, true, true, true, false],
            [true, true, true, false, true],
            [false, false, true, true, true],
            [true, false, true, false, true]
        ]
        return patterns[seed]
    }

    /// Returns mocked W/L record based on team ID
    private func mockedRecord(teamId: Int) -> (wins: Int, losses: Int) {
        let wins = 3 + (teamId % 4)
        let losses = 1 + (teamId % 3)
        return (wins, losses)
    }

    /// Returns mocked stat values for a given stat key
    private func mockedStatValues(statKey: String, teamAId: Int, teamBId: Int) -> (Int, Int) {
        let baseValues: [String: (Int, Int)] = [
            "points": (68, 72),
            "two_pm": (18, 20),
            "three_pm": (6, 8),
            "pfs": (14, 12),
            "as": (15, 13),
            "blk": (3, 5),
            "st": (7, 6),
            "tr": (35, 38),
            "to": (10, 12),
            "or": (8, 10),
            "dr": (22, 25),
            "fta": (12, 14),
            "ftm": (9, 11),
            "minutes": (40, 40),
            "two_pa": (30, 28),
            "three_pa": (16, 20),
            "fga": (52, 48),
            "fgm": (24, 28),
            "tfs": (4, 3)
        ]

        if let base = baseValues[statKey] {
            // Add small deterministic variance based on team IDs
            let varA = (teamAId * 3) % 5
            let varB = (teamBId * 3) % 5
            return (base.0 + varA, base.1 + varB)
        }

        // Fallback for unknown stats
        let a = 10 + (teamAId % 10)
        let b = 10 + (teamBId % 10)
        return (a, b)
    }
}
