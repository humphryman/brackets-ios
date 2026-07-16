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
    @State private var windowProgress: CGFloat = 0
    @State private var gestureStartProgress: CGFloat? = nil
    @State private var liveRefreshTimer: Timer?
    @State private var brackets: [BracketInfo] = []
    @State private var selectedBracketName: String?
    @State private var didInitBracket = false

    private var hasLiveGames: Bool {
        games.contains(where: { $0.isLive })
    }

    private var selectedBracket: BracketInfo? {
        brackets.first { $0.name == selectedBracketName }
    }

    private var activeType: String {
        (selectedBracket?.type ?? tournament.bracketType)?.lowercased() ?? ""
    }

    private var bracketGames: [Game] {
        guard !brackets.isEmpty, let name = selectedBracketName else { return games }
        return games.filter { $0.bracket == name }
    }

    private var rounds: [BracketRound] {
        buildRounds()
    }

    var body: some View {
        VStack(spacing: 0) {
            if brackets.count >= 2 {
                ChipCarousel(items: brackets.map(\.name), label: { $0 }, selected: $selectedBracketName)
                    .padding(.vertical, AppTheme.Spacing.small)
                    .onChange(of: selectedBracketName) {
                        windowProgress = 0
                    }
            }
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
                bracketContent()
            }
            }
        }
        .task {
            await loadGames()
            startLiveRefreshIfNeeded()
        }
        .onDisappear {
            stopLiveRefresh()
        }
    }

    // MARK: - Layout Constants

    private let matchupCardWidth: CGFloat = 180
    private let matchupCardHeight: CGFloat = 118
    private let connectorWidth: CGFloat = 36

    private var columnWidth: CGFloat {
        matchupCardWidth + connectorWidth
    }

    // MARK: - Windowed Layout Math

    private var baseSpacing: CGFloat { activeType == "semifinals" ? 80 : 24 }
    private var step0: CGFloat { matchupCardHeight + baseSpacing }
    private var maxWindow: CGFloat { CGFloat(max(0, rounds.count - 2)) }

    /// A round's clamped distance from the window's left edge (0 = condensed left
    /// column, 1 = spread right column). Only the shared middle round has a
    /// fractional distance mid-transition, so only it morphs.
    private func distance(_ roundIndex: Int) -> CGFloat {
        min(max(CGFloat(roundIndex) - windowProgress, 0), 1)
    }

    private func spacing(_ d: CGFloat) -> CGFloat {
        (baseSpacing + matchupCardHeight) * pow(2, d) - matchupCardHeight
    }

    private func topPad(_ d: CGFloat) -> CGFloat {
        step0 * (pow(2, d) - 1) / 2
    }

    private func roundLabel(_ name: String) -> String {
        switch name {
        case "16vos de Final": return "16vos"
        case "Octavos de Final": return "8vos"
        case "Cuartos de Final": return "4tos"
        case "Semifinal": return "Semis"
        case "Final": return "Final"
        default: return name
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func bracketContent() -> some View {
        let labels = rounds.map { roundLabel($0.name) }
        // GeometryReader bounds this whole area to the screen width, so the wide
        // rounds HStack can't expand the layout (which would otherwise stretch the
        // StageSelector's own GeometryReader and shift the columns).
        GeometryReader { geo in
            VStack(spacing: 0) {
                StageSelector(labels: labels, windowProgress: $windowProgress, maxWindow: maxWindow)
                    .padding(.horizontal, AppTheme.Layout.screenPadding)
                    .padding(.top, AppTheme.Spacing.medium)
                    .padding(.bottom, 12)

                morphingBracket(pageWidth: geo.size.width)
            }
        }
    }

    private func morphingBracket(pageWidth: CGFloat) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            // Position each round column by its distance from the window, and only
            // render the columns near the visible window. This makes the scroll
            // content height track the VISIBLE window's tallest column (fewer games
            // = shorter scroll) instead of the whole bracket's tallest round — so
            // settling on a smaller round no longer leaves dead black space below.
            ZStack(alignment: .topLeading) {
                ForEach(Array(rounds.enumerated()), id: \.element.name) { roundIndex, round in
                    let rel = CGFloat(roundIndex) - windowProgress
                    if rel > -1 && rel < 2.2 {
                        roundColumn(round: round, roundIndex: roundIndex)
                            .offset(x: rel * columnWidth + AppTheme.Layout.screenPadding)
                    }
                }
            }
            .frame(width: pageWidth, alignment: .leading)
            .padding(.bottom, 100)
        }
        .frame(width: pageWidth)
        .clipped()
        .simultaneousGesture(windowDragGesture())
    }

    private func windowDragGesture() -> some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                guard maxWindow > 0 else { return }
                if abs(value.translation.width) > abs(value.translation.height) {
                    let start = gestureStartProgress ?? windowProgress
                    if gestureStartProgress == nil { gestureStartProgress = start }
                    windowProgress = min(max(start - value.translation.width / columnWidth, 0), maxWindow)
                }
            }
            .onEnded { value in
                let start = gestureStartProgress ?? windowProgress
                gestureStartProgress = nil
                guard maxWindow > 0 else { return }
                let target: CGFloat
                if abs(value.predictedEndTranslation.width) > columnWidth * 0.5 {
                    target = value.translation.width < 0 ? start + 1 : start - 1
                } else {
                    target = windowProgress.rounded()
                }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                    windowProgress = min(max(target, 0), maxWindow)
                }
            }
    }

    // MARK: - Bracket Content

    private func roundHeaderLabel(_ round: BracketRound) -> some View {
        Text(round.name.uppercased())
            .font(.system(size: 11, weight: .bold))
            .tracking(0.5)
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color(white: 0.13)))
    }

    // MARK: - Round Column

    private func roundColumn(round: BracketRound, roundIndex: Int) -> some View {
        let d = distance(roundIndex)
        let topOffset = topPad(d)
        let spacing = spacing(d)

        let isLastRound = roundIndex == rounds.count - 1

        return HStack(alignment: .top, spacing: 0) {
            // Matchup cards (+ Tercer Lugar stacked below, if present)
            VStack(spacing: 0) {
                if isLastRound {
                    roundHeaderLabel(round)
                        .frame(width: matchupCardWidth, alignment: .leading)
                        .padding(.bottom, 10)
                }

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
                connectorsColumn(roundIndex: roundIndex, matchups: round.matchups)
                    .padding(.top, topOffset)
            }
        }
    }

    // MARK: - Matchup Card

    @ViewBuilder
    private func matchupCard(matchup: BracketMatchup) -> some View {
        let isLive = matchup.game?.isLive ?? false
        let decided = matchup.homeIsWinner || matchup.awayIsWinner

        let card = VStack(spacing: 0) {
            // Header: clock + date + time, with a separator below
            if let time = matchup.scheduledTime {
                matchupTimeLine(time)
                    .padding(.top, 8)
                    .padding(.bottom, 6)
                Rectangle()
                    .fill(Color(white: 0.2))
                    .frame(height: 1)
                    .padding(.bottom, 4)
            }

            // Home team row
            teamRow(
                team: matchup.homeTeam,
                score: matchup.homeScore,
                isWinner: matchup.homeIsWinner,
                hasGame: matchup.hasGame,
                decided: decided,
                placeholderName: matchup.homePlaceholder
            )

            // Away team row
            teamRow(
                team: matchup.awayTeam,
                score: matchup.awayScore,
                isWinner: matchup.awayIsWinner,
                hasGame: matchup.hasGame,
                decided: decided,
                placeholderName: matchup.awayPlaceholder
            )

        }
        .frame(width: matchupCardWidth, height: matchupCardHeight, alignment: matchup.scheduledTime == nil ? .center : .top)
        .background(Color(white: 0.09))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(alignment: .top) {
            if isLive {
                BracketLiveBadge()
                    .offset(y: -9)
            }
        }
        if let game = matchup.game {
            NavigationLink {
                if game.isLive {
                    LiveGameDetailView(game: game, tournamentId: tournament.id, tournamentName: tournament.name)
                } else if game.isFinished {
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

    private func teamRow(team: Team?, score: Int?, isWinner: Bool, hasGame: Bool, decided: Bool, placeholderName: String? = nil) -> some View {
        let displayName = team?.name ?? placeholderName ?? "TBD"
        let hasTeam = team != nil || placeholderName != nil
        // Unplayed / no-game rows use white; on a decided game the loser stays dimmed.
        let nameColor: Color
        if isWinner {
            nameColor = AppTheme.Colors.primaryText
        } else if decided {
            nameColor = hasTeam ? Color(white: 0.55) : Color(white: 0.3)
        } else {
            nameColor = hasTeam ? AppTheme.Colors.primaryText : Color(white: 0.3)
        }
        let scoreText = score.map { "\($0)" } ?? "-"
        let scoreColor: Color = isWinner ? AppTheme.Colors.accent : (score != nil ? Color(white: 0.5) : Color(white: 0.3))

        return HStack(spacing: 8) {
            teamAvatar(name: displayName, isWinner: isWinner, hasTeam: hasTeam)

            Text(displayName)
                .font(.system(size: 12, weight: isWinner ? .bold : .semibold))
                .foregroundStyle(nameColor)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(scoreText)
                .font(.system(size: 17, weight: .heavy))
                .foregroundStyle(scoreColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isWinner ? AppTheme.Colors.accent.opacity(0.10) : Color.clear)
                .padding(.horizontal, 4)
        )
    }

    private func teamAvatar(name: String, isWinner: Bool, hasTeam: Bool) -> some View {
        let words = name.split(separator: " ")
        let initials: String = words.count >= 2
            ? String(words[0].prefix(1) + words[1].prefix(1)).uppercased()
            : String(name.prefix(2)).uppercased()
        return Circle()
            .fill(isWinner ? AppTheme.Colors.accent : Color(white: 0.18))
            .frame(width: 22, height: 22)
            .overlay(
                Text(initials)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(isWinner ? AppTheme.Colors.accentText : Color(white: 0.5))
            )
    }

    @ViewBuilder
    private func matchupTimeLine(_ time: Date) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "clock")
                .font(.system(size: 9))
            Text(Self.footerDateFormatter.string(from: time))
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 10)
    }

    private static let footerDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_MX")
        f.timeZone = AppConfig.DateTime.apiTimeZone
        f.dateFormat = "d MMM · h:mm a"
        f.amSymbol = "AM"
        f.pmSymbol = "PM"
        return f
    }()

    // MARK: - Connector Lines

    private func connectorsColumn(roundIndex: Int, matchups: [BracketMatchup]) -> some View {
        let spacing = spacing(distance(roundIndex))
        let cardH = matchupCardHeight
        let pairCount = matchups.count / 2

        return VStack(spacing: 0) {
            ForEach(0..<max(pairCount, 1), id: \.self) { i in
                connectorPair(cardHeight: cardH, spacing: spacing)
                    .padding(.bottom, i < pairCount - 1 ? spacing : 0)
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
        let gray = Color(white: 0.25)

        return Path { path in
            path.move(to: CGPoint(x: 0, y: topMid))
            path.addLine(to: CGPoint(x: midX, y: topMid))
            path.addLine(to: CGPoint(x: midX, y: bottomMid))
            path.move(to: CGPoint(x: 0, y: bottomMid))
            path.addLine(to: CGPoint(x: midX, y: bottomMid))
            path.move(to: CGPoint(x: midX, y: centerY))
            path.addLine(to: CGPoint(x: connectorWidth, y: centerY))
        }
        .stroke(gray, lineWidth: 1.5)
        .frame(width: connectorWidth, height: pairHeight)
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
        let stageGames = bracketGames.filter { game in
            guard let gameStage = game.stage else { return false }
            return stageMatches(gameStage: gameStage, target: stage)
        }
        // Final and Tercer Lugar have a single slot — bracket_id is meaningless there,
        // so accept the lone game if one exists. QF (4 slots) and SF (2 slots) must
        // always match by bracket_id to avoid replicating a single game across slots.
        let stageLower = stage.lowercased()
        let isSingleSlotStage = stageLower == "final" || stageLower == "tercer lugar"
        if isSingleSlotStage, stageGames.count == 1 { return stageGames.first }
        return stageGames.first { $0.bracketId == slot }
    }

    private func placeholderForSlot(stage: String, slot: Int) -> GamePlaceholder? {
        selectedBracket?.gamePlaceholders?.first { ph in
            guard let phStage = ph.stage else { return false }
            return stageMatches(gameStage: phStage, target: stage) && ph.bracketId == slot
        }
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
                game: game,
                scheduledTime: game.gameTime,
                venue: game.venue
            )
        }

        let placeholder = placeholderForSlot(stage: stage, slot: slot)
        return BracketMatchup(
            homeTeam: propagation?.home,
            homeScore: nil,
            homeIsWinner: false,
            awayTeam: propagation?.away,
            awayScore: nil,
            awayIsWinner: false,
            hasGame: false,
            game: nil,
            homePlaceholder: propagation?.home == nil ? placeholder?.teamA : nil,
            awayPlaceholder: propagation?.away == nil ? placeholder?.teamB : nil,
            scheduledTime: placeholder?.gameTime,
            venue: placeholder?.venue
        )
    }

    // MARK: - Build Rounds

    private func buildRounds() -> [BracketRound] {
        let type = activeType
        var rounds: [BracketRound] = []
        var previous: [BracketMatchup] = []

        // Dieciseisavos round (only for round-of-32 brackets)
        if type == "dieciseisavos" {
            let r32 = (1...16).map { slot in
                buildMatchup(stage: "Dieciseisavos de final", slot: slot, propagation: nil)
            }
            rounds.append(BracketRound(name: "16vos de Final", matchups: r32))
            previous = r32
        }

        // Octavos round (dieciseisavos or octavos)
        if type == "dieciseisavos" || type == "octavos" {
            let r16 = (1...8).map { slot -> BracketMatchup in
                let prop: (home: Team?, away: Team?)? = previous.isEmpty
                    ? nil
                    : propagatedPair(from: previous, slotIndex: slot - 1, useLoser: false)
                return buildMatchup(stage: "Octavos de final", slot: slot, propagation: prop)
            }
            rounds.append(BracketRound(name: "Octavos de Final", matchups: r16))
            previous = r16
        }

        // QF round (dieciseisavos, octavos, or quarterfinals)
        if type == "dieciseisavos" || type == "octavos" || type == "quarterfinals" {
            let qfMatchups = (1...4).map { slot -> BracketMatchup in
                let prop: (home: Team?, away: Team?)? = previous.isEmpty
                    ? nil
                    : propagatedPair(from: previous, slotIndex: slot - 1, useLoser: false)
                return buildMatchup(stage: "Cuartos de Final", slot: slot, propagation: prop)
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
            brackets = (response.brackets ?? []).sorted { ($0.position ?? Int.max) < ($1.position ?? Int.max) }
            if !didInitBracket {
                selectedBracketName = brackets.first?.name
                didInitBracket = true
            }
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    // MARK: - Live Refresh

    private func startLiveRefreshIfNeeded() {
        guard hasLiveGames else { return }
        stopLiveRefresh()
        liveRefreshTimer = Timer.scheduledTimer(withTimeInterval: 7, repeats: true) { _ in
            Task { await refreshLiveGames() }
        }
    }

    private func stopLiveRefresh() {
        liveRefreshTimer?.invalidate()
        liveRefreshTimer = nil
    }

    private func refreshLiveGames() async {
        let liveGames = games.filter { $0.isLive }
        guard !liveGames.isEmpty else { return }

        var updates: [Int: Game] = [:]
        var anyEnded = false

        for game in liveGames {
            do {
                let response = try await APIService.shared.fetchGameDetail(
                    tournamentId: tournament.id,
                    gameId: game.id
                )
                updates[game.id] = makeUpdatedGame(from: response.game, original: game)
                if response.game.isFinished {
                    anyEnded = true
                }
            } catch {
                print("❌ Bracket live refresh error for game \(game.id): \(error)")
            }
        }

        await MainActor.run {
            if !updates.isEmpty {
                games = games.map { updates[$0.id] ?? $0 }
            }
        }

        if anyEnded {
            do {
                let response = try await APIService.shared.fetchGamesResponse(for: tournament.id)
                await MainActor.run {
                    games = response.allGames
                    if !hasLiveGames { stopLiveRefresh() }
                }
            } catch {
                print("❌ Bracket games refetch error after live game ended: \(error)")
            }
        }
    }

    private func makeUpdatedGame(from detail: GameDetail, original: Game) -> Game {
        let mappedStats: [TeamStat]? = detail.teamStats?.map { stat in
            TeamStat(
                id: stat.id,
                score: stat.score,
                result: stat.result,
                teamName: stat.teamName,
                teamLogo: stat.teamLogo
            )
        }
        return Game(
            id: detail.id,
            gameTime: detail.gameTime ?? original.gameTime,
            stage: detail.stage ?? original.stage,
            bracketId: original.bracketId,
            venue: detail.venue ?? original.venue,
            isLive: !detail.isFinished,
            period: detail.period ?? original.period,
            teamStats: mappedStats ?? original.teamStats,
            group: original.group,
            bracket: original.bracket
        )
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
    var homePlaceholder: String? = nil
    var awayPlaceholder: String? = nil
    var scheduledTime: Date? = nil
    var venue: Venue? = nil
}

struct BracketRound: Identifiable {
    let name: String
    let matchups: [BracketMatchup]
    var thirdPlace: BracketMatchup? = nil

    var id: String { name }
}

// MARK: - Live Badge

private struct BracketLiveBadge: View {
    @State private var pulse: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(AppTheme.Colors.live)
                .frame(width: 5, height: 5)
                .opacity(pulse ? 1.0 : 0.4)
                .animation(
                    .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                    value: pulse
                )
            Text("EN VIVO")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(AppTheme.Colors.live)
                .tracking(0.5)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(Color(white: 0.08))
        )
        .overlay(
            Capsule()
                .stroke(AppTheme.Colors.live, lineWidth: 1)
        )
        .onAppear { pulse = true }
    }
}

// MARK: - Stage Selector

/// Apple Sports–style stage bar: a row of stage labels with a draggable 2-wide
/// highlight marking the two stages currently visible. Bound to the same
/// `windowProgress` the bracket content uses, so selector-drag and content-swipe
/// stay in sync.
struct StageSelector: View {
    let labels: [String]
    @Binding var windowProgress: CGFloat
    let maxWindow: CGFloat

    @State private var dragStart: CGFloat?

    var body: some View {
        GeometryReader { geo in
            let n = max(labels.count, 1)
            let segW = geo.size.width / CGFloat(n)
            let h = geo.size.height

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(white: 0.10))

                // 2-wide highlight window with chevron affordances
                HStack {
                    Image(systemName: "chevron.left")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(maxWindow > 0 ? Color(white: 0.7) : .clear)
                .padding(.horizontal, 8)
                .frame(width: segW * 2, height: h - 8)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.06)))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(AppTheme.Colors.accent, lineWidth: 2))
                .offset(x: windowProgress * segW)

                // Stage labels (drawn over the highlight)
                HStack(spacing: 0) {
                    ForEach(Array(labels.enumerated()), id: \.offset) { i, label in
                        Text(label)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(isActive(i) ? AppTheme.Colors.primaryText : Color(white: 0.45))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(width: segW)
                    }
                }
            }
            .frame(height: h)
            .contentShape(Rectangle())
            .gesture(dragGesture(segW: segW))
        }
        .frame(height: 44)
    }

    private func isActive(_ i: Int) -> Bool {
        CGFloat(i) >= windowProgress - 0.5 && CGFloat(i) <= windowProgress + 1.5
    }

    private func dragGesture(segW: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 5)
            .onChanged { value in
                guard maxWindow > 0, segW > 0 else { return }
                let start = dragStart ?? windowProgress
                if dragStart == nil { dragStart = start }
                windowProgress = min(max(start + value.translation.width / segW, 0), maxWindow)
            }
            .onEnded { _ in
                dragStart = nil
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    windowProgress = min(max(windowProgress.rounded(), 0), maxWindow)
                }
            }
    }
}

#Preview("Stage selector") {
    struct Wrap: View {
        @State var progress: CGFloat = 0
        var body: some View {
            StageSelector(
                labels: ["16vos", "8vos", "4tos", "Semis", "Final"],
                windowProgress: $progress,
                maxWindow: 3
            )
            .padding()
        }
    }
    return ZStack { Color.black.ignoresSafeArea(); Wrap() }
}
