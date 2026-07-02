//
//  GamesListView.swift
//  Brackets
//
//  Created by Humberto on 16/02/26.
//

import SwiftUI

private extension DateFormatter {
    static let yyyyMMdd: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = AppConfig.DateTime.apiTimeZone
        return f
    }()
}

/// Colors specific to the redesigned game card.
private enum GameCardPalette {
    static let cardBackground = Color(white: 0.11)
    static let semifinalBanner = Color(red: 0.23, green: 0.21, blue: 0.90)
    static let stageTagFill = Color(white: 0.2)
    static let groupTagFill = Color(red: 35/255, green: 14/255, blue: 46/255)
}

/// A single filter chip — either a group ("Grupo 1") or a playoff bracket ("Playoffs").
struct GameGroupChip: Identifiable, Equatable, Hashable {
    enum Kind { case group, bracket }
    let name: String
    let kind: Kind
    var id: String { "\(kind == .group ? "g" : "b")-\(name)" }
}


enum GameFilter: String, CaseIterable {
    case live = "En Vivo"
    case upcoming = "Próximos"
    case completed = "Resultados"
}

struct GamesListView: View {
    let tournament: Tournament
    @State private var gamesResponse: GamesResponse?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedFilter: GameFilter = .upcoming
    @State private var selectedChip: GameGroupChip?
    @State private var didInitChip = false
    @State private var liveGameDetails: [Int: GameDetailResponse] = [:]
    @State private var liveRefreshTimer: Timer?

    private var hasLiveGames: Bool {
        gamesResponse?.allGames.contains { $0.isLive } ?? false
    }

    private var availableFilters: [GameFilter] {
        var filters: [GameFilter] = []
        if hasLiveGames { filters.append(.live) }
        filters.append(contentsOf: [.upcoming, .completed])
        return filters
    }

    private var chips: [GameGroupChip] {
        guard let response = gamesResponse else { return [] }
        // Only groups/brackets that have games under the active top-tab.
        let all = response.allGames.filter { matchesTab($0) }

        let groupChips = Set(all.compactMap { $0.group })
            .sorted { lhs, rhs in
                switch (trailingInt(lhs), trailingInt(rhs)) {
                case let (l?, r?) where l != r: return l < r
                default: return lhs < rhs
                }
            }
            .map { GameGroupChip(name: $0, kind: .group) }

        let order = Dictionary(
            (response.brackets ?? []).compactMap { info in info.position.map { (info.name, $0) } },
            uniquingKeysWith: { first, _ in first })
        let bracketChips = Set(all.compactMap { $0.bracket })
            .sorted { lhs, rhs in
                switch (order[lhs], order[rhs]) {
                case let (l?, r?) where l != r: return l < r
                case (nil, _?): return false
                case (_?, nil): return true
                default: return lhs < rhs
                }
            }
            .map { GameGroupChip(name: $0, kind: .bracket) }

        return groupChips + bracketChips
    }

    private func trailingInt(_ s: String) -> Int? {
        if let last = s.split(separator: " ").last, let n = Int(last) { return n }
        return nil
    }

    private func matchesTab(_ game: Game) -> Bool {
        switch selectedFilter {
        case .live: return game.isLive
        case .upcoming: return !game.isFinished && !game.isLive
        case .completed: return game.isFinished && !game.isLive
        }
    }

    private func matches(_ game: Game, _ chip: GameGroupChip) -> Bool {
        switch chip.kind {
        case .group: return game.group == chip.name
        case .bracket: return game.bracket == chip.name
        }
    }

    private func ensureValidChip() {
        let list = chips
        guard !list.isEmpty else { selectedChip = nil; return }
        let hasGames: (GameGroupChip) -> Bool = { chip in
            self.gamesResponse?.allGames.contains { self.matchesTab($0) && self.matches($0, chip) } ?? false
        }
        if let sel = selectedChip, list.contains(sel), hasGames(sel) { return }
        selectedChip = list.first(where: hasGames) ?? list.first
    }

    /// On a top-tab change, always jump to the first available group for that tab.
    private func selectFirstChip() {
        selectedChip = chips.first
    }

    var filteredGames: [GamesResponse.DateGroup] {
        guard let gamesResponse = gamesResponse else { return [] }
        let chip = selectedChip
        let groups = gamesResponse.games.map { dateGroup in
            GamesResponse.DateGroup(
                date: dateGroup.date,
                games: dateGroup.games.filter { game in
                    guard matchesTab(game) else { return false }
                    if let chip { return matches(game, chip) }
                    return true
                }
            )
        }.filter { !$0.games.isEmpty }
        let ascending = selectedFilter != .completed
        return groups.sorted { ascending ? $0.date < $1.date : $0.date > $1.date }
    }
    
    var body: some View {
        ZStack {
            if isLoading {
                AppTheme.LoadingView(message: "Loading games...")
            } else if let errorMessage = errorMessage {
                AppTheme.ErrorView(message: errorMessage) {
                    Task {
                        await loadGames()
                    }
                }
            } else if let _ = gamesResponse {
                VStack(spacing: 0) {
                    // Top filter (Próximos / Resultados / En Vivo)
                    GameFilterView(selectedFilter: $selectedFilter, filters: availableFilters)
                        .padding(.horizontal, AppTheme.Layout.screenPadding)
                        .padding(.top, AppTheme.Spacing.medium)
                        .padding(.bottom, AppTheme.Spacing.small)

                    // Group / bracket carousel
                    ChipCarousel(items: chips, label: \.name, selected: $selectedChip)
                        .padding(.bottom, AppTheme.Spacing.medium)
                        .onChange(of: selectedFilter) { selectFirstChip() }

                    if filteredGames.isEmpty {
                        AppTheme.EmptyStateView(
                            icon: "basketball",
                            message: "No hay juegos agendados."
                        )
                        .frame(maxHeight: .infinity)
                    } else {
                        // Games List
                        ScrollViewReader { proxy in
                            ScrollView {
                                VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                                    ForEach(filteredGames, id: \.date) { dateGroup in
                                        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                                            // Date Header with calendar icon + count
                                            HStack(spacing: 8) {
                                                Image(systemName: "calendar")
                                                    .font(.system(size: 14, weight: .semibold))
                                                    .foregroundStyle(AppTheme.Colors.accent)

                                                Text(formatDateHeader(dateGroup.date))
                                                    .font(.system(size: 16, weight: .bold))
                                                    .foregroundStyle(AppTheme.Colors.primaryText)

                                                Text(dateGroup.games.count == 1 ? "1 Juego" : "\(dateGroup.games.count) Juegos")
                                                    .font(.system(size: 12, weight: .semibold))
                                                    .foregroundStyle(AppTheme.Colors.secondaryText)
                                                    .padding(.horizontal, 10)
                                                    .padding(.vertical, 4)
                                                    .background(Capsule().fill(Color(white: 0.2)))
                                            }
                                            .padding(.horizontal, AppTheme.Layout.screenPadding)

                                            // Games for this date
                                            ForEach(dateGroup.games) { game in
                                                if game.isLive {
                                                    NavigationLink {
                                                        LiveGameDetailView(game: game, tournamentId: tournament.id, tournamentName: tournament.name)
                                                    } label: {
                                                        LiveGameCard(game: game, detail: liveGameDetails[game.id], tournamentId: tournament.id)
                                                            .padding(.horizontal, AppTheme.Layout.screenPadding)
                                                    }
                                                    .buttonStyle(.plain)
                                                } else if game.isFinished {
                                                    NavigationLink {
                                                        GameResultView(game: game, tournamentId: tournament.id, tournamentName: tournament.name)
                                                    } label: {
                                                        GameCard(game: game)
                                                            .padding(.horizontal, AppTheme.Layout.screenPadding)
                                                    }
                                                    .buttonStyle(.plain)
                                                } else {
                                                    NavigationLink {
                                                        UpcomingGameView(game: game, tournamentId: tournament.id)
                                                    } label: {
                                                        GameCard(game: game)
                                                            .padding(.horizontal, AppTheme.Layout.screenPadding)
                                                    }
                                                    .buttonStyle(.plain)
                                                }
                                            }
                                        }
                                        .id(dateGroup.date)
                                    }
                                }
                                .padding(.bottom, AppTheme.Layout.large)
                            }
                            .onChange(of: selectedFilter) {
                                scrollToInitialPosition(proxy: proxy)
                            }
                            .onAppear {
                                scrollToInitialPosition(proxy: proxy)
                            }
                        }
                    }
                }
            } else {
                AppTheme.EmptyStateView(
                    icon: "sportscourt",
                    message: "No hay juegos agendados."
                )
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

    private func startLiveRefreshIfNeeded() {
        guard hasLiveGames else { return }
        // Auto-select live filter when live games exist
        if selectedFilter == .upcoming {
            selectedFilter = .live
        }
        stopLiveRefresh()
        liveRefreshTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
            Task {
                await refreshLiveGames()
            }
        }
        // Initial fetch
        Task { await refreshLiveGames() }
    }

    private func stopLiveRefresh() {
        liveRefreshTimer?.invalidate()
        liveRefreshTimer = nil
    }

    private func refreshLiveGames() async {
        guard let games = gamesResponse?.allGames.filter({ $0.isLive }) else { return }

        var anyEnded = false
        for game in games {
            do {
                let detail = try await APIService.shared.fetchGameDetail(
                    tournamentId: tournament.id,
                    gameId: game.id
                )
                await MainActor.run {
                    liveGameDetails[game.id] = detail
                }
                if detail.game.isFinished {
                    anyEnded = true
                }
            } catch {
                print("❌ Live game refresh error for game \(game.id): \(error)")
            }
        }

        if anyEnded {
            do {
                let response = try await APIService.shared.fetchGamesResponse(for: tournament.id)
                await MainActor.run {
                    gamesResponse = response
                    if !hasLiveGames {
                        if selectedFilter == .live {
                            selectedFilter = .upcoming
                        }
                        stopLiveRefresh()
                    }
                }
            } catch {
                print("❌ Games refetch error after live game ended: \(error)")
            }
        }
    }
    
    private func loadGames() async {
        isLoading = true
        errorMessage = nil
        
        do {
            gamesResponse = try await APIService.shared.fetchGamesResponse(for: tournament.id)
            if !didInitChip {
                ensureValidChip()
                didInitChip = true
            }
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    private func scrollToInitialPosition(proxy: ScrollViewProxy) {
        let targetDate: String?

        if selectedFilter == .completed {
            targetDate = filteredGames.first?.date
        } else {
            let today = DateFormatter.yyyyMMdd.string(from: Date())
            targetDate = filteredGames
                .map(\.date)
                .filter { $0 >= today }
                .sorted()
                .first
        }

        if let targetDate {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation {
                    proxy.scrollTo(targetDate, anchor: .top)
                }
            }
        }
    }

    private func formatDateHeader(_ dateString: String) -> String {
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        parser.timeZone = AppConfig.DateTime.apiTimeZone
        guard let date = parser.date(from: dateString) else { return dateString }

        let f = DateFormatter()
        f.locale = Locale(identifier: "es_MX")
        f.timeZone = AppConfig.DateTime.apiTimeZone

        f.dateFormat = "EEEE"
        let weekday = f.string(from: date).capitalized
        f.dateFormat = "MMMM"
        let month = f.string(from: date).capitalized
        f.dateFormat = "d"
        let day = f.string(from: date)
        return "\(weekday), \(day) de \(month)"
    }
}

/// Filter buttons at the top
struct GameFilterView: View {
    @Binding var selectedFilter: GameFilter
    var filters: [GameFilter] = GameFilter.allCases

    var body: some View {
        HStack(spacing: AppTheme.Spacing.small) {
            ForEach(filters, id: \.self) { filter in
                if filter == .live {
                    LiveFilterButton(isSelected: selectedFilter == filter) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedFilter = filter
                        }
                    }
                } else {
                    FilterButton(
                        title: filter.rawValue,
                        isSelected: selectedFilter == filter
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedFilter = filter
                        }
                    }
                }
            }

            Spacer()
        }
    }
}

/// Live filter button with red dot
struct LiveFilterButton: View {
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(Color.red)
                .frame(width: 10, height: 10)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(isSelected ? Color.red.opacity(0.3) : Color.clear)
            )
            .overlay(
                Capsule()
                    .stroke(Color.red, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

/// Individual filter button
struct FilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isSelected ? AppTheme.Colors.accentText : AppTheme.Colors.primaryText)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(isSelected ? AppTheme.Colors.accent : Color(white: 0.2))
                )
        }
        .buttonStyle(.plain)
    }
}

/// Unified game card: optional Final/Semifinal banner, teams, score/time, location, tags.
struct GameCard: View {
    let game: Game

    private var isFinal: Bool { game.stage?.lowercased() == "final" }
    private var isSemifinal: Bool { game.stage?.lowercased().contains("semifinal") == true }

    private var bannerText: String? {
        if isFinal { return "Final" }
        if isSemifinal { return "Semifinal" }
        return nil
    }

    private var stageTagText: String? {
        guard bannerText == nil, let stage = game.stage, !stage.isEmpty else { return nil }
        return stage.capitalized
    }

    private var groupTagText: String? {
        game.group ?? game.bracket
    }

    var body: some View {
        VStack(spacing: 0) {
            if let bannerText {
                HStack {
                    Text(bannerText)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(isFinal ? AppTheme.Colors.accentText : .white)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isFinal ? AppTheme.Colors.accent : GameCardPalette.semifinalBanner)
            }

            VStack(spacing: 14) {
                HStack(spacing: AppTheme.Spacing.large) {
                    TeamSection(
                        teamName: game.homeTeam?.name ?? "TBD",
                        isWinner: game.isFinished && game.winner?.id == game.homeTeam?.id,
                        imageURL: game.homeTeam?.fullImageURL
                    )
                    .frame(maxWidth: .infinity)

                    CenterSection(game: game)
                        .frame(width: 130)

                    TeamSection(
                        teamName: game.awayTeam?.name ?? "TBD",
                        isWinner: game.isFinished && game.winner?.id == game.awayTeam?.id,
                        imageURL: game.awayTeam?.fullImageURL
                    )
                    .frame(maxWidth: .infinity)
                }

                if let venue = game.venue {
                    VenueLabel(venue: venue)
                }

                if stageTagText != nil || groupTagText != nil {
                    HStack(spacing: 8) {
                        if let stageTagText {
                            tag(stageTagText, fill: GameCardPalette.stageTagFill, textColor: AppTheme.Colors.secondaryText)
                        }
                        if let groupTagText {
                            tag(groupTagText, fill: GameCardPalette.groupTagFill, textColor: .white)
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(GameCardPalette.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large))
    }

    private func tag(_ text: String, fill: Color, textColor: Color) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(textColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(fill))
    }
}

/// Team logo (winner gets a lime ring) with the name below.
struct TeamSection: View {
    let teamName: String
    let isWinner: Bool
    var imageURL: String? = nil

    var body: some View {
        VStack(spacing: AppTheme.Spacing.small) {
            ZStack {
                logoCircle
                if isWinner {
                    Circle()
                        .stroke(AppTheme.Colors.accent, lineWidth: 2)
                        .frame(width: 54, height: 54)
                }
            }
            Text(teamName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.primaryText)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
    }

    @ViewBuilder
    private var logoCircle: some View {
        if let imageURL, let url = URL(string: imageURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill().frame(width: 46, height: 46).clipShape(Circle())
                default:
                    initialsCircle
                }
            }
        } else {
            initialsCircle
        }
    }

    private var initialsCircle: some View {
        Circle()
            .fill(Color(white: 0.15))
            .frame(width: 46, height: 46)
            .overlay(
                Text(initials)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(AppTheme.Colors.primaryText)
            )
    }

    private var initials: String {
        let words = teamName.split(separator: " ")
        if words.count >= 2 {
            return String(words[0].prefix(1) + words[1].prefix(1)).uppercased()
        } else if let first = words.first {
            return String(first.prefix(3)).uppercased()
        }
        return "TBD"
    }
}

/// Center of the card: score (winner in accent) when finished, else the start time.
struct CenterSection: View {
    let game: Game

    private var homeIsWinner: Bool { game.isFinished && game.winner?.id == game.homeTeam?.id }
    private var awayIsWinner: Bool { game.isFinished && game.winner?.id == game.awayTeam?.id }

    var body: some View {
        if game.isFinished {
            HStack(spacing: 8) {
                Text("\(game.homeScore ?? 0)")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(homeIsWinner ? AppTheme.Colors.accent : AppTheme.Colors.primaryText)
                Text("-")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(Color(white: 0.45))
                Text("\(game.awayScore ?? 0)")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(awayIsWinner ? AppTheme.Colors.accent : AppTheme.Colors.primaryText)
            }
            .fixedSize()
        } else if let gameTime = game.gameTime {
            Text(Self.timeFormatter.string(from: gameTime))
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppTheme.Colors.primaryText)
                .fixedSize()
        } else {
            Text("—")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color(white: 0.45))
        }
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_MX")
        f.timeZone = AppConfig.DateTime.apiTimeZone
        f.dateFormat = "h:mm a"
        return f
    }()
}

// MARK: - Live Game Card

struct LiveGameCard: View {
    let game: Game
    let detail: GameDetailResponse?
    let tournamentId: Int
    var showQuarterScores: Bool = false

    @State private var homeScalePulse = false
    @State private var awayScalePulse = false
    @State private var periodScalePulse = false
    @State private var lastHomeScore: Int?
    @State private var lastAwayScore: Int?
    @State private var lastPeriod: String?

    // Use teamStats as primary source — consistent team order for names, logos, and scores
    private var homeTeamStat: GameDetailTeamStat? {
        guard let teams = detail?.game.teamStats, !teams.isEmpty else { return nil }
        return teams[0]
    }

    private var awayTeamStat: GameDetailTeamStat? {
        guard let teams = detail?.game.teamStats, teams.count > 1 else { return nil }
        return teams[1]
    }

    private var homeScore: Int {
        homeTeamStat?.score ?? game.homeScore ?? 0
    }

    private var awayScore: Int {
        awayTeamStat?.score ?? game.awayScore ?? 0
    }

    private var period: String {
        if let detailPeriod = detail?.game.period, !detailPeriod.isEmpty {
            return detailPeriod
        }
        return game.period ?? ""
    }

    private var homeTeamName: String {
        homeTeamStat?.teamName ?? game.homeTeam?.name ?? "TBD"
    }

    private var awayTeamName: String {
        awayTeamStat?.teamName ?? game.awayTeam?.name ?? "TBD"
    }

    private var homeLogoURL: String? {
        homeTeamStat?.fullImageURL ?? game.homeTeam?.fullImageURL
    }

    private var awayLogoURL: String? {
        awayTeamStat?.fullImageURL ?? game.awayTeam?.fullImageURL
    }

    var body: some View {
        VStack(spacing: 12) {
            // Stage badge
            if let stage = game.stage {
                Text(stage)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppTheme.Colors.accentText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(AppTheme.Colors.accent))
            }

            // Teams + Score
            HStack(spacing: 0) {
                // Home Team
                VStack(spacing: 6) {
                    liveTeamLogo(urlString: homeLogoURL, name: homeTeamName)
                    Text(homeTeamName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity)

                // Score + Period
                VStack(spacing: 4) {
                    if !period.isEmpty {
                        Text(period)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(AppTheme.Colors.accent)
                            .scaleEffect(periodScalePulse ? 1.3 : 1.0)
                    }

                    HStack(spacing: 4) {
                        Text("\(homeScore)")
                            .font(.system(size: 28, weight: .heavy))
                            .foregroundStyle(.white)
                            .frame(minWidth: 36)
                            .scaleEffect(homeScalePulse ? 1.3 : 1.0)
                        Text("-")
                            .font(.system(size: 20))
                            .foregroundStyle(Color(white: 0.4))
                        Text("\(awayScore)")
                            .font(.system(size: 28, weight: .heavy))
                            .foregroundStyle(.white)
                            .frame(minWidth: 36)
                            .scaleEffect(awayScalePulse ? 1.3 : 1.0)
                    }
                    .fixedSize()

                    // EN VIVO indicator
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                        Text("EN VIVO")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.red)
                    }
                }
                .frame(width: 120)

                // Away Team
                VStack(spacing: 6) {
                    liveTeamLogo(urlString: awayLogoURL, name: awayTeamName)
                    Text(awayTeamName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity)
            }

            if showQuarterScores,
               (homeTeamStat?.hasQuarterScores ?? false) || (awayTeamStat?.hasQuarterScores ?? false) {
                Divider().background(Color(white: 0.2))
                QuarterScoresTable(
                    teamAName: homeTeamName,
                    teamAScores: homeTeamStat?.quarterScores,
                    teamATotal: homeTeamStat?.score,
                    teamBName: awayTeamName,
                    teamBScores: awayTeamStat?.quarterScores,
                    teamBTotal: awayTeamStat?.score
                )
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large)
                .fill(Color(white: 0.1))
                .stroke(Color.red.opacity(0.5), lineWidth: 1.5)
        )
        .onChange(of: homeScore) { oldValue, newValue in
            if lastHomeScore != nil && oldValue != newValue {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                    homeScalePulse = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                        homeScalePulse = false
                    }
                }
            }
            lastHomeScore = newValue
        }
        .onChange(of: awayScore) { oldValue, newValue in
            if lastAwayScore != nil && oldValue != newValue {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                    awayScalePulse = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                        awayScalePulse = false
                    }
                }
            }
            lastAwayScore = newValue
        }
        .onChange(of: period) { oldValue, newValue in
            if lastPeriod != nil && oldValue != newValue {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                    periodScalePulse = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                        periodScalePulse = false
                    }
                }
            }
            lastPeriod = newValue
        }
        .onAppear {
            lastHomeScore = homeScore
            lastAwayScore = awayScore
            lastPeriod = period
        }
    }

    @ViewBuilder
    private func liveTeamLogo(urlString: String?, name: String) -> some View {
        if let urlString, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 56, height: 56)
                        .clipShape(Circle())
                default:
                    liveTeamInitials(name: name)
                }
            }
        } else {
            liveTeamInitials(name: name)
        }
    }

    private func liveTeamInitials(name: String) -> some View {
        let words = name.split(separator: " ")
        let initials = words.count >= 2
            ? String(words[0].prefix(1) + words[1].prefix(1)).uppercased()
            : String(name.prefix(3)).uppercased()
        return Circle()
            .fill(Color(white: 0.2))
            .frame(width: 56, height: 56)
            .overlay(
                Text(initials)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color(white: 0.5))
            )
    }

    private func formatLiveDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_MX")
        formatter.timeZone = AppConfig.DateTime.apiTimeZone
        formatter.dateFormat = "MMM dd, yyyy"
        return formatter.string(from: date).capitalized
    }
}

#Preview("Group carousel") {
    struct Wrap: View {
        @State var sel: GameGroupChip? = GameGroupChip(name: "Grupo 1", kind: .group)
        var chips: [GameGroupChip] {
            (1...13).map { GameGroupChip(name: "Grupo \($0)", kind: .group) }
            + ["Playoffs", "Playoffs 2", "Playoffs 3"].map { GameGroupChip(name: $0, kind: .bracket) }
        }
        var body: some View {
            ChipCarousel(items: chips, label: \.name, selected: $sel)
        }
    }
    return ZStack { Color.black.ignoresSafeArea(); Wrap() }
}

#Preview("Game cards") {
    func sample(stage: String, group: String?, bracket: String?, finished: Bool) -> Game {
        Game(
            id: Int.random(in: 1...99999),
            gameTime: Date(),
            stage: stage,
            bracketId: nil,
            venue: Venue(name: "Polideportivo Central", courtNumber: "1", lat: nil, lng: nil),
            teamStats: [
                TeamStat(id: 1, score: finished ? 48 : nil, result: finished ? "Won" : nil, teamName: "Sonora A", teamLogo: nil),
                TeamStat(id: 2, score: finished ? 43 : nil, result: finished ? "Lost" : nil, teamName: "Sinaloa B", teamLogo: nil)
            ],
            group: group,
            bracket: bracket
        )
    }
    return ScrollView {
        VStack(spacing: 16) {
            GameCard(game: sample(stage: "Final", group: nil, bracket: "Playoffs", finished: true))
            GameCard(game: sample(stage: "Semifinal", group: nil, bracket: "Playoffs", finished: true))
            GameCard(game: sample(stage: "Ronda regular", group: "Grupo 1", bracket: nil, finished: true))
            GameCard(game: sample(stage: "Ronda regular", group: "Grupo 1", bracket: nil, finished: false))
        }
        .padding()
    }
    .background(Color.black)
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        GamesListView(
            tournament: Tournament(
                id: 1,
                name: "Juvenil Varonil",
                gender: .male,
                teamCount: 8,
                image: nil
            )
        )
    }
}
