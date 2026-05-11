//
//  BracketView.swift
//  Brackets
//

import SwiftUI

struct BracketView: View {
    let tournament: Tournament
    @State private var games: [Game] = []
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
            } else if games.isEmpty {
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

    private let matchupCardWidth: CGFloat = 180
    private let matchupCardHeight: CGFloat = 110
    private let connectorWidth: CGFloat = 36
    private let teamLogoSize: CGFloat = 40

    private var roundColumnWidth: CGFloat {
        matchupCardWidth + connectorWidth
    }

    // MARK: - Pager

    private func bracketPager(pageWidth: CGFloat) -> some View {
        let bracketType = tournament.bracketType?.lowercased() ?? ""
        let needsPaging = rounds.count > 2

        if needsPaging {
            return AnyView(pagedBracket(pageWidth: pageWidth))
        } else {
            return AnyView(staticBracket())
        }
    }

    private func staticBracket() -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            bracketContent
                .padding(.bottom, 100)
                .padding(.top, AppTheme.Spacing.medium)
        }
        .padding(.leading, 0)
        .padding(.trailing, 0)
    }

    private func pagedBracket(pageWidth: CGFloat) -> some View {
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
                        .frame(width: matchupCardWidth, alignment: .center)
                        .padding(.trailing, index < rounds.count - 1 ? connectorWidth : 0)
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
            // Matchup cards (+ Tercer Lugar stacked below, if present)
            VStack(spacing: 0) {
                VStack(spacing: spacing) {
                    ForEach(Array(round.matchups.enumerated()), id: \.offset) { _, matchup in
                        matchupCard(matchup: matchup)
                    }
                }

                if let third = round.thirdPlace {
                    Spacer().frame(height: 60)
                    Text("3er Lugar")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color(white: 0.45))
                        .frame(width: matchupCardWidth, alignment: .center)
                    Spacer().frame(height: 6)
                    matchupCard(matchup: third)
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
                    GameResultView(game: game, tournamentId: tournament.id, tournamentName: tournament.name)
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
        HStack(spacing: 6) {
            // Team logo
            if let team = team {
                teamLogoView(team: team, isWinner: isWinner)
            } else {
                placeholderLogo()
            }

            // Team name — fills all available space
            Text(team?.name ?? "TBD")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(team != nil ? (isWinner ? AppTheme.Colors.primaryText : Color(white: 0.5)) : Color(white: 0.25))
                .lineLimit(2)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Score
            Text(score.map { "\($0)" } ?? "-")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(isWinner ? AppTheme.Colors.accent : (score != nil ? AppTheme.Colors.primaryText : Color(white: 0.3)))
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(isWinner ? AppTheme.Colors.accent.opacity(0.2) : Color(white: 0.15))
                )
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    // MARK: - Team Logo

    @ViewBuilder
    private func teamLogoView(team: Team, isWinner: Bool = false) -> some View {
        let borderColor = isWinner ? AppTheme.Colors.accent : Color(white: 0.2)
        let borderWidth: CGFloat = isWinner ? 2.5 : 1

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
                                .stroke(borderColor, lineWidth: borderWidth)
                        )
                default:
                    logoPlaceholderWithInitials(name: team.name, isWinner: isWinner)
                }
            }
        } else {
            logoPlaceholderWithInitials(name: team.name, isWinner: isWinner)
        }
    }

    private func logoPlaceholderWithInitials(name: String, isWinner: Bool = false) -> some View {
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
                    .stroke(isWinner ? AppTheme.Colors.accent : Color(white: 0.2), lineWidth: isWinner ? 2.5 : 1)
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
        let bracketType = tournament.bracketType?.lowercased() ?? ""
        let baseSpacing: CGFloat = bracketType == "semifinals" ? 80 : 24
        if roundIndex == 0 { return baseSpacing }
        return matchupSpacing(for: roundIndex - 1) * 2 + matchupCardHeight
    }

    private func topPadding(for roundIndex: Int) -> CGFloat {
        if roundIndex == 0 { return 0 }
        return topPadding(for: roundIndex - 1) + (matchupSpacing(for: roundIndex - 1) + matchupCardHeight) / 2
    }

    // MARK: - Slot-Based Lookup

    private func stageMatches(gameStage: String, target: String) -> Bool {
        let g = gameStage.lowercased()
        let t = target.lowercased()
        if t == "final" { return g == "final" }
        if t == "semifinal" { return g == "semifinal" || g == "semifinales" }
        return g == t
    }

    private func gameForSlot(stage: String, slot: Int) -> Game? {
        let stageGames = games.filter { game in
            guard let gameStage = game.stage else { return false }
            return stageMatches(gameStage: gameStage, target: stage)
        }
        // If only one game in this stage (e.g., Final, Tercer Lugar), placement is unambiguous.
        if stageGames.count == 1 { return stageGames.first }
        return stageGames.first { $0.bracketId == slot }
    }

    private func winner(of matchup: BracketMatchup) -> Team? {
        if matchup.homeIsWinner { return matchup.homeTeam }
        if matchup.awayIsWinner { return matchup.awayTeam }
        return nil
    }

    private func loser(of matchup: BracketMatchup) -> Team? {
        if matchup.homeIsWinner { return matchup.awayTeam }
        if matchup.awayIsWinner { return matchup.homeTeam }
        return nil
    }

    /// For next-round slot `slotIndex` (0-based), source from previous matchups at
    /// indices slotIndex*2 and slotIndex*2 + 1. Returns home/away pair (winners or losers).
    private func propagatedPair(from previous: [BracketMatchup], slotIndex: Int, useLoser: Bool) -> (home: Team?, away: Team?) {
        let aIdx = slotIndex * 2
        let bIdx = aIdx + 1
        let a = aIdx < previous.count ? previous[aIdx] : nil
        let b = bIdx < previous.count ? previous[bIdx] : nil
        return (
            home: a.flatMap { useLoser ? loser(of: $0) : winner(of: $0) },
            away: b.flatMap { useLoser ? loser(of: $0) : winner(of: $0) }
        )
    }

    private func buildMatchup(stage: String, slot: Int, propagation: (home: Team?, away: Team?)?) -> BracketMatchup {
        if let game = gameForSlot(stage: stage, slot: slot) {
            return BracketMatchup(
                homeTeam: game.homeTeam,
                homeScore: game.homeScore,
                homeIsWinner: game.isFinished && game.winner?.id == game.homeTeam?.id,
                awayTeam: game.awayTeam,
                awayScore: game.awayScore,
                awayIsWinner: game.isFinished && game.winner?.id == game.awayTeam?.id,
                hasGame: true,
                game: game
            )
        }
        return BracketMatchup(
            homeTeam: propagation?.home,
            homeScore: nil,
            homeIsWinner: false,
            awayTeam: propagation?.away,
            awayScore: nil,
            awayIsWinner: false,
            hasGame: false,
            game: nil
        )
    }

    // MARK: - Build Rounds

    private func buildRounds() -> [BracketRound] {
        let bracketType = tournament.bracketType?.lowercased() ?? ""

        var rounds: [BracketRound] = []
        var previous: [BracketMatchup] = []

        // QF round (only for quarterfinals-type tournaments)
        if bracketType == "quarterfinals" {
            let qfMatchups = (1...4).map { slot in
                buildMatchup(stage: "Cuartos de Final", slot: slot, propagation: nil)
            }
            rounds.append(BracketRound(name: "Cuartos de Final", matchups: qfMatchups))
            previous = qfMatchups
        }

        // SF round (always present)
        let sfMatchups = (1...2).map { slot -> BracketMatchup in
            let prop: (home: Team?, away: Team?)? = previous.isEmpty
                ? nil
                : propagatedPair(from: previous, slotIndex: slot - 1, useLoser: false)
            return buildMatchup(stage: "Semifinal", slot: slot, propagation: prop)
        }
        rounds.append(BracketRound(name: "Semifinal", matchups: sfMatchups))

        // Final + Tercer Lugar (combined column)
        let finalProp = propagatedPair(from: sfMatchups, slotIndex: 0, useLoser: false)
        let finalMatch = buildMatchup(stage: "Final", slot: 1, propagation: finalProp)

        let thirdProp = propagatedPair(from: sfMatchups, slotIndex: 0, useLoser: true)
        let thirdMatch = buildMatchup(stage: "Tercer Lugar", slot: 1, propagation: thirdProp)

        rounds.append(BracketRound(name: "Final", matchups: [finalMatch], thirdPlace: thirdMatch))

        return rounds
    }

    // MARK: - Data Loading

    private func loadGames() async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await APIService.shared.fetchGamesResponse(for: tournament.id)
            games = response.allGames
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
    var thirdPlace: BracketMatchup? = nil

    var id: String { name }
}
