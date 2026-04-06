//
//  BracketView.swift
//  Brackets
//

import SwiftUI

struct BracketView: View {
    let tournament: Tournament
    @State private var games: [Game] = []
    @State private var standings: [TeamStanding] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var currentPage: Int = 0
    @State private var dragOffset: CGFloat = 0

    private var rounds: [BracketRound] {
        buildRounds()
    }

    var body: some View {
        ZStack {
            if isLoading {
                AppTheme.LoadingView(message: "Loading bracket...")
            } else if let errorMessage = errorMessage {
                AppTheme.ErrorView(message: errorMessage) {
                    Task { await loadGames() }
                }
            } else if rounds.isEmpty {
                AppTheme.EmptyStateView(
                    icon: "square.grid.2x2",
                    message: "No hay bracket disponible."
                )
            } else {
                GeometryReader { geo in
                    bracketPager(pageWidth: geo.size.width)
                }
            }
        }
        .task {
            await loadGames()
        }
    }

    // MARK: - Layout Constants

    private let matchupCardWidth: CGFloat = 140
    private let matchupCardHeight: CGFloat = 110
    private let connectorWidth: CGFloat = 36
    private let teamLogoSize: CGFloat = 40

    private var roundColumnWidth: CGFloat {
        matchupCardWidth + connectorWidth
    }

    // MARK: - Pager

    private func bracketPager(pageWidth: CGFloat) -> some View {
        let roundStep = roundColumnWidth
        let maxPage = max(0, rounds.count - 2)
        let baseOffset = -CGFloat(currentPage) * roundStep + AppTheme.Layout.screenPadding

        return ScrollView(.vertical, showsIndicators: false) {
            bracketContent
                .padding(.bottom, 100)
                .padding(.top, AppTheme.Spacing.medium)
        }
        .offset(x: baseOffset + dragOffset)
        .highPriorityGesture(
            DragGesture(minimumDistance: 30)
                .onChanged { value in
                    // Only track horizontal drags
                    if abs(value.translation.width) > abs(value.translation.height) {
                        dragOffset = value.translation.width
                    }
                }
                .onEnded { value in
                    let threshold: CGFloat = 50
                    withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) {
                        if value.translation.width < -threshold {
                            currentPage = min(currentPage + 1, maxPage)
                        } else if value.translation.width > threshold {
                            currentPage = max(currentPage - 1, 0)
                        }
                        dragOffset = 0
                    }
                }
        )
        .clipped()
    }

    // MARK: - Bracket Content

    private var bracketContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Round headers
            HStack(alignment: .top, spacing: 0) {
                ForEach(Array(rounds.enumerated()), id: \.element.name) { index, round in
                    Text(round.name.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color(white: 0.45))
                        .frame(width: roundColumnWidth, alignment: .leading)
                }
            }
            .padding(.bottom, 20)

            // Bracket body
            HStack(alignment: .top, spacing: 0) {
                ForEach(Array(rounds.enumerated()), id: \.element.name) { roundIndex, round in
                    roundColumn(round: round, roundIndex: roundIndex)
                }
            }
        }
    }

    // MARK: - Round Column

    private func roundColumn(round: BracketRound, roundIndex: Int) -> some View {
        let topOffset = topPadding(for: roundIndex)
        let spacing = matchupSpacing(for: roundIndex)

        return HStack(alignment: .top, spacing: 0) {
            // Matchup cards
            VStack(spacing: spacing) {
                ForEach(Array(round.matchups.enumerated()), id: \.offset) { _, matchup in
                    matchupCard(matchup: matchup)
                }
            }
            .padding(.top, topOffset)

            // Connector lines to next round
            if roundIndex < rounds.count - 1 {
                connectorsColumn(roundIndex: roundIndex, matchCount: round.matchups.count / 2)
                    .padding(.top, topOffset)
            }
        }
    }

    // MARK: - Matchup Card

    @ViewBuilder
    private func matchupCard(matchup: BracketMatchup) -> some View {
        let card = VStack(spacing: 0) {
            // Home team row
            teamRow(
                team: matchup.homeTeam,
                score: matchup.homeScore,
                isWinner: matchup.homeIsWinner,
                hasGame: matchup.hasGame
            )

            Rectangle()
                .fill(Color(white: 0.2))
                .frame(height: 1)
                .padding(.horizontal, 8)

            // Away team row
            teamRow(
                team: matchup.awayTeam,
                score: matchup.awayScore,
                isWinner: matchup.awayIsWinner,
                hasGame: matchup.hasGame
            )
        }
        .frame(width: matchupCardWidth)
        .background(Color(white: 0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(matchup.game != nil ? Color(white: 0.45) : Color(white: 0.2), lineWidth: 1)
        )
        if let game = matchup.game {
            NavigationLink {
                if game.isFinished {
                    GameResultView(game: game, tournamentId: tournament.id)
                } else {
                    UpcomingGameView(game: game, tournamentId: tournament.id)
                }
            } label: {
                card
            }
            .buttonStyle(.plain)
        } else {
            card
        }
    }

    private func teamRow(team: Team?, score: Int?, isWinner: Bool, hasGame: Bool) -> some View {
        HStack(alignment: .top, spacing: 8) {
            // Team logo + name
            VStack(spacing: 3) {
                if let team = team {
                    teamLogoView(team: team)
                } else {
                    placeholderLogo()
                }

                Text(team?.name ?? "TBD")
                    .font(.system(size: 11, weight: isWinner ? .bold : .medium))
                    .foregroundStyle(team != nil ? (isWinner ? AppTheme.Colors.primaryText : Color(white: 0.5)) : Color(white: 0.25))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(width: teamLogoSize + 10)
            }

            Spacer(minLength: 2)

            // Score
            Text(score.map { "\($0)" } ?? "-")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(isWinner ? AppTheme.Colors.accent : (score != nil ? AppTheme.Colors.primaryText : Color(white: 0.3)))
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(isWinner ? AppTheme.Colors.accent.opacity(0.2) : Color(white: 0.15))
                )
                .padding(.top, 8)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    // MARK: - Team Logo

    @ViewBuilder
    private func teamLogoView(team: Team) -> some View {
        if let imageURL = team.fullImageURL, let url = URL(string: imageURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: teamLogoSize, height: teamLogoSize)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(white: 0.2), lineWidth: 1)
                        )
                default:
                    logoPlaceholderWithInitials(name: team.name)
                }
            }
        } else {
            logoPlaceholderWithInitials(name: team.name)
        }
    }

    private func logoPlaceholderWithInitials(name: String) -> some View {
        let words = name.split(separator: " ")
        let initials: String = if words.count >= 2 {
            String(words[0].prefix(1) + words[1].prefix(1)).uppercased()
        } else {
            String(name.prefix(2)).uppercased()
        }
        return RoundedRectangle(cornerRadius: 8)
            .fill(Color(white: 0.15))
            .frame(width: teamLogoSize, height: teamLogoSize)
            .overlay(
                Text(initials)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color(white: 0.4))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(white: 0.2), lineWidth: 1)
            )
    }

    private func placeholderLogo() -> some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color(white: 0.08))
            .frame(width: teamLogoSize, height: teamLogoSize)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(white: 0.15), lineWidth: 1)
            )
            .overlay(
                Image(systemName: "questionmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(white: 0.2))
            )
    }

    // MARK: - Connector Lines

    private func connectorsColumn(roundIndex: Int, matchCount: Int) -> some View {
        let spacing = matchupSpacing(for: roundIndex)
        let cardH = matchupCardHeight

        return VStack(spacing: 0) {
            ForEach(0..<max(matchCount, 1), id: \.self) { i in
                connectorPair(cardHeight: cardH, spacing: spacing)
                    .padding(.bottom, i < matchCount - 1 ? spacing : 0)
            }
        }
        .frame(width: connectorWidth)
    }

    private func connectorPair(cardHeight: CGFloat, spacing: CGFloat) -> some View {
        // Connects two matchup cards to a single output point
        let pairHeight = cardHeight * 2 + spacing
        let topMid = cardHeight / 2
        let bottomMid = cardHeight + spacing + cardHeight / 2
        let centerY = pairHeight / 2
        let midX = connectorWidth / 2

        return Path { path in
            // Line from top card center-right to vertical bar
            path.move(to: CGPoint(x: 0, y: topMid))
            path.addLine(to: CGPoint(x: midX, y: topMid))

            // Vertical bar
            path.addLine(to: CGPoint(x: midX, y: bottomMid))

            // Line from bottom card center-right to vertical bar
            path.move(to: CGPoint(x: 0, y: bottomMid))
            path.addLine(to: CGPoint(x: midX, y: bottomMid))

            // Horizontal line from center of vertical bar to next round
            path.move(to: CGPoint(x: midX, y: centerY))
            path.addLine(to: CGPoint(x: connectorWidth, y: centerY))
        }
        .stroke(Color(white: 0.25), lineWidth: 1.5)
        .frame(width: connectorWidth, height: pairHeight)
    }

    // MARK: - Layout Helpers

    private func matchupSpacing(for roundIndex: Int) -> CGFloat {
        if roundIndex == 0 { return 24 }
        return matchupSpacing(for: roundIndex - 1) * 2 + matchupCardHeight
    }

    private func topPadding(for roundIndex: Int) -> CGFloat {
        if roundIndex == 0 { return 0 }
        return topPadding(for: roundIndex - 1) + (matchupSpacing(for: roundIndex - 1) + matchupCardHeight) / 2
    }

    // MARK: - Build Rounds

    private func buildRounds() -> [BracketRound] {
        let bracketType = tournament.bracketType?.lowercased() ?? ""

        switch bracketType {
        case "quarterfinals":
            return buildQuarterfinalsBracket()
        case "semifinals":
            return buildStageRounds([
                ("Semifinal", "Semifinal", 2),
                ("Final", "Final", 1)
            ])
        default:
            return buildStageRounds([
                ("Semifinal", "Semifinal", 2),
                ("Final", "Final", 1)
            ])
        }
    }

    /// Build quarterfinals bracket using standings for seeding
    private func buildQuarterfinalsBracket() -> [BracketRound] {
        // Seeding pairs: (seed1 vs seed8), (seed4 vs seed5), (seed2 vs seed7), (seed3 vs seed6)
        let seedPairs: [(Int, Int)] = [(1, 8), (4, 5), (2, 7), (3, 6)]

        // Quarterfinals matchups from standings + actual game data
        var qfMatchups: [BracketMatchup] = []
        let qfGames = gamesForStage("Cuartos de Final")

        print("🏀 QF games found: \(qfGames.count)")
        for g in qfGames {
            print("  Game \(g.id): \(g.homeTeam?.name ?? "?") vs \(g.awayTeam?.name ?? "?") stage=\(g.stage ?? "nil")")
        }

        for (seedA, seedB) in seedPairs {
            let teamA = teamFromSeed(seedA)
            let teamB = teamFromSeed(seedB)

            // Find corresponding game by matching team IDs or names
            let game = findGame(teamA: teamA, teamB: teamB, in: qfGames)
            print("🏀 Seed \(seedA) (\(teamA?.name ?? "nil") id:\(teamA?.id ?? -1)) vs Seed \(seedB) (\(teamB?.name ?? "nil") id:\(teamB?.id ?? -1)) → game: \(game?.id ?? -1)")

            if let game = game {
                qfMatchups.append(BracketMatchup(
                    homeTeam: game.homeTeam,
                    homeScore: game.homeScore,
                    homeIsWinner: game.isFinished && game.winner?.id == game.homeTeam?.id,
                    awayTeam: game.awayTeam,
                    awayScore: game.awayScore,
                    awayIsWinner: game.isFinished && game.winner?.id == game.awayTeam?.id,
                    hasGame: true,
                    game: game
                ))
            } else {
                // No game yet — show seeded teams without scores
                qfMatchups.append(BracketMatchup(
                    homeTeam: teamA,
                    homeScore: nil,
                    homeIsWinner: false,
                    awayTeam: teamB,
                    awayScore: nil,
                    awayIsWinner: false,
                    hasGame: false,
                    game: nil
                ))
            }
        }

        // Semis and Finals from actual games
        let laterRounds = buildStageRounds([
            ("Semifinal", "Semifinal", 2),
            ("Final", "Final", 1)
        ])

        return [BracketRound(name: "Cuartos de Final", matchups: qfMatchups)] + laterRounds
    }

    /// Convert a standing (by seed/position) to a Team
    private func teamFromSeed(_ seed: Int) -> Team? {
        guard seed > 0, seed <= standings.count else { return nil }
        let standing = standings[seed - 1]
        return Team(id: standing.id, name: standing.teamName, image: standing.teamLogo)
    }

    /// Find a game that matches two teams (in either order) by ID or name
    private func findGame(teamA: Team?, teamB: Team?, in stageGames: [Game]) -> Game? {
        guard let a = teamA, let b = teamB else { return nil }

        // Try matching by team ID first
        if let game = stageGames.first(where: { game in
            let ids = [game.homeTeam?.id, game.awayTeam?.id]
            return ids.contains(a.id) && ids.contains(b.id)
        }) {
            return game
        }

        // Fallback: match by team name
        let nameA = a.name.lowercased()
        let nameB = b.name.lowercased()
        return stageGames.first { game in
            let names = [game.homeTeam?.name.lowercased(), game.awayTeam?.name.lowercased()]
            return names.contains(nameA) && names.contains(nameB)
        }
    }

    /// Get games filtered by stage name
    private func gamesForStage(_ stage: String) -> [Game] {
        let target = stage.lowercased()
        return games.filter { game in
            guard let gameStage = game.stage?.lowercased() else { return false }
            if target == "final" {
                return gameStage == "final"
            }
            if target == "semifinal" {
                return gameStage == "semifinal" || gameStage == "semifinales"
            }
            return gameStage.contains(target)
        }
    }

    /// Build rounds from stage definitions, using actual game data
    private func buildStageRounds(_ stages: [(stage: String, name: String, expectedMatchups: Int)]) -> [BracketRound] {
        var rounds: [BracketRound] = []
        for (stage, name, expectedMatchups) in stages {
            let stageGames = gamesForStage(stage)

            var matchups: [BracketMatchup] = []
            for game in stageGames {
                matchups.append(BracketMatchup(
                    homeTeam: game.homeTeam,
                    homeScore: game.homeScore,
                    homeIsWinner: game.isFinished && game.winner?.id == game.homeTeam?.id,
                    awayTeam: game.awayTeam,
                    awayScore: game.awayScore,
                    awayIsWinner: game.isFinished && game.winner?.id == game.awayTeam?.id,
                    hasGame: true,
                    game: game
                ))
            }

            // Fill remaining with placeholder matchups
            while matchups.count < expectedMatchups {
                matchups.append(BracketMatchup(
                    homeTeam: nil, homeScore: nil, homeIsWinner: false,
                    awayTeam: nil, awayScore: nil, awayIsWinner: false,
                    hasGame: false,
                    game: nil
                ))
            }

            rounds.append(BracketRound(name: name, matchups: matchups))
        }
        return rounds
    }

    // MARK: - Data Loading

    private func loadGames() async {
        isLoading = true
        errorMessage = nil

        do {
            async let gamesRequest = APIService.shared.fetchGamesResponse(for: tournament.id)
            async let standingsRequest = APIService.shared.fetchStandings(for: tournament.id)

            let response = try await gamesRequest
            games = response.allGames

            let standingsResult = try await standingsRequest
            switch standingsResult {
            case .flat(let s):
                standings = s
            case .groups(let groups):
                // Combine all group standings into a flat list sorted by total points
                standings = groups.flatMap(\.standings).sorted { $0.total > $1.total }
            }

            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}

// MARK: - Models

struct BracketMatchup {
    let homeTeam: Team?
    let homeScore: Int?
    let homeIsWinner: Bool
    let awayTeam: Team?
    let awayScore: Int?
    let awayIsWinner: Bool
    let hasGame: Bool
    let game: Game?
}

struct BracketRound: Identifiable {
    let name: String
    let matchups: [BracketMatchup]

    var id: String { name }
}
