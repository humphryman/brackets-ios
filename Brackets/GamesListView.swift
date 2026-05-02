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

enum GameFilter: String, CaseIterable {
    case live = "En Vivo"
    case all = "Todos"
    case upcoming = "Próximos"
    case completed = "Resultados"
}

struct GamesListView: View {
    let tournament: Tournament
    @State private var gamesResponse: GamesResponse?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedFilter: GameFilter = .all
    @State private var liveGameDetails: [Int: GameDetailResponse] = [:]
    @State private var liveRefreshTimer: Timer?

    private var hasLiveGames: Bool {
        gamesResponse?.allGames.contains { $0.isLive } ?? false
    }

    private var availableFilters: [GameFilter] {
        var filters: [GameFilter] = []
        if hasLiveGames {
            filters.append(.live)
        }
        filters.append(contentsOf: [.all, .upcoming, .completed])
        return filters
    }

    var filteredGames: [GamesResponse.DateGroup] {
        guard let gamesResponse = gamesResponse else { return [] }

        let groups: [GamesResponse.DateGroup]
        switch selectedFilter {
        case .live:
            groups = gamesResponse.games.map { dateGroup in
                GamesResponse.DateGroup(
                    date: dateGroup.date,
                    games: dateGroup.games.filter { $0.isLive }
                )
            }.filter { !$0.games.isEmpty }
        case .all:
            groups = gamesResponse.games
        case .upcoming:
            groups = gamesResponse.games.map { dateGroup in
                GamesResponse.DateGroup(
                    date: dateGroup.date,
                    games: dateGroup.games.filter { !$0.isFinished && !$0.isLive }
                )
            }.filter { !$0.games.isEmpty }
        case .completed:
            groups = gamesResponse.games.map { dateGroup in
                GamesResponse.DateGroup(
                    date: dateGroup.date,
                    games: dateGroup.games.filter { $0.isFinished && !$0.isLive }
                )
            }.filter { !$0.games.isEmpty }
        }

        // Sort date groups so future dates come first
        return groups.sorted { $0.date > $1.date }
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
                    // Filter Buttons
                    GameFilterView(selectedFilter: $selectedFilter, filters: availableFilters)
                        .padding(.horizontal, AppTheme.Layout.screenPadding)
                        .padding(.top, AppTheme.Spacing.medium)
                        .padding(.bottom, AppTheme.Spacing.large)

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
                                            // Date Header with calendar icon
                                            HStack(spacing: 8) {
                                                Image(systemName: "calendar")
                                                    .font(.system(size: 14, weight: .semibold))
                                                    .foregroundStyle(AppTheme.Colors.accent)

                                                Text(formatDateHeader(dateGroup.date))
                                                    .font(.system(size: 16, weight: .bold))
                                                    .foregroundStyle(AppTheme.Colors.primaryText)
                                            }
                                            .padding(.horizontal, AppTheme.Layout.screenPadding)

                                            // Games for this date
                                            ForEach(dateGroup.games) { game in
                                                if game.isLive {
                                                    NavigationLink {
                                                        LiveGameDetailView(game: game, tournamentId: tournament.id)
                                                    } label: {
                                                        LiveGameCard(game: game, detail: liveGameDetails[game.id], tournamentId: tournament.id)
                                                            .padding(.horizontal, AppTheme.Layout.screenPadding)
                                                    }
                                                    .buttonStyle(.plain)
                                                } else if game.isFinished {
                                                    NavigationLink {
                                                        GameResultView(game: game, tournamentId: tournament.id)
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
        if selectedFilter == .all {
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
        for game in games {
            do {
                let detail = try await APIService.shared.fetchGameDetail(
                    tournamentId: tournament.id,
                    gameId: game.id
                )
                await MainActor.run {
                    liveGameDetails[game.id] = detail
                }
            } catch {
                print("❌ Live game refresh error for game \(game.id): \(error)")
            }
        }
    }
    
    private func loadGames() async {
        isLoading = true
        errorMessage = nil
        
        do {
            gamesResponse = try await APIService.shared.fetchGamesResponse(for: tournament.id)
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

        if let date = parser.date(from: dateString) {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "es_MX")
            formatter.timeZone = AppConfig.DateTime.apiTimeZone
            formatter.dateFormat = "MMMM dd, yyyy"
            return formatter.string(from: date).capitalized
        }

        return dateString
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

/// Main game card matching the exact design
struct GameCard: View {
    let game: Game
    
    private var isQuarterfinal: Bool {
        game.stage?.lowercased().contains("cuartos") == true
    }

    private var isSemifinal: Bool {
        game.stage?.lowercased().contains("semifinal") == true
    }

    private var isFinal: Bool {
        guard let stage = game.stage?.lowercased() else { return false }
        return stage == "final"
    }

    private var isPlayoffGame: Bool {
        isQuarterfinal || isSemifinal || isFinal
    }

    private var stageBadgeText: String? {
        if isQuarterfinal { return "Cuartos de Final" }
        if isSemifinal { return "Semifinal" }
        if isFinal { return "Final" }
        return nil
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: AppTheme.Spacing.standard) {
                if stageBadgeText != nil {
                    Spacer().frame(height: 16)
                }

                HStack(spacing: AppTheme.Spacing.large) {
                    // Home Team
                    TeamSection(
                        teamName: game.homeTeam?.name ?? "TBD",
                        initials: getInitials(game.homeTeam?.name ?? "TBD"),
                        isWinner: game.isFinished && game.winner?.id == game.homeTeam?.id,
                        imageURL: game.homeTeam?.fullImageURL,
                        forceDarkText: isFinal
                    )
                    .frame(maxWidth: .infinity)

                    // Center: Score or VS with time
                    CenterSection(game: game, forceDarkText: isFinal)
                        .frame(width: 150)

                    // Away Team
                    TeamSection(
                        teamName: game.awayTeam?.name ?? "TBD",
                        initials: getInitials(game.awayTeam?.name ?? "TBD"),
                        isWinner: game.isFinished && game.winner?.id == game.awayTeam?.id,
                        imageURL: game.awayTeam?.fullImageURL,
                        forceDarkText: isFinal
                    )
                    .frame(maxWidth: .infinity)
                }

                // Stadium/Location
                if let venue = game.venue {
                    Text(venue.name + (venue.courtNumber.map { " - \($0)" } ?? ""))
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(isFinal ? Color.black.opacity(0.6) : Color(white: 0.5))
                }
            }

            // Stage badge
            if let badge = stageBadgeText {
                Text(badge.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(isFinal ? .white : AppTheme.Colors.accentText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(isFinal ? Color.black.opacity(0.3) : AppTheme.Colors.accent))
                    .padding(.trailing, 10)
            }
        }
        .padding(.horizontal, AppTheme.Spacing.large)
        .padding(.vertical, AppTheme.Spacing.large)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large)
                .fill(isFinal ? AppTheme.Colors.accent : Color(white: 0.1))
                .stroke((isQuarterfinal || isSemifinal) ? AppTheme.Colors.accent.opacity(0.6) : Color(white: 1.0).opacity(isFinal ? 0 : 0.18), lineWidth: (isQuarterfinal || isSemifinal) ? 1.5 : 1)
        )
    }
    
    private func getInitials(_ teamName: String) -> String {
        let words = teamName.split(separator: " ")
        if words.count >= 2 {
            return String(words[0].prefix(1) + words[1].prefix(1)).uppercased()
        } else if let first = words.first {
            return String(first.prefix(3)).uppercased()
        }
        return "TBD"
    }
}

/// Team display with circle and name
struct TeamSection: View {
    let teamName: String
    let initials: String
    let isWinner: Bool
    var imageURL: String? = nil
    var forceDarkText: Bool = false

    var body: some View {
        VStack(spacing: AppTheme.Spacing.small) {
            // Team circle with logo or initials
            ZStack {
                if let imageURL, let url = URL(string: imageURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 60, height: 60)
                                .clipShape(Circle())
                        default:
                            initialsCircle
                        }
                    }
                } else {
                    initialsCircle
                }

                // Winner ring / Final border
                if isWinner || forceDarkText {
                    Circle()
                        .stroke(forceDarkText ? Color.black : AppTheme.Colors.accent, lineWidth: 2)
                        .frame(width: 68, height: 68)
                }
            }

            // Team Name
            Text(teamName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(forceDarkText ? .black : AppTheme.Colors.primaryText)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
    }

    private var initialsCircle: some View {
        Circle()
            .fill(isWinner ? (forceDarkText ? Color.black : AppTheme.Colors.accent) : Color(white: 0.15))
            .frame(width: 60, height: 60)
            .overlay(
                Text(initials)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(isWinner ? AppTheme.Colors.accentText : (forceDarkText ? .black : AppTheme.Colors.primaryText))
            )
    }
}

/// Center section with score or time
struct CenterSection: View {
    let game: Game
    var forceDarkText: Bool = false

    var homeIsWinner: Bool { game.isFinished && game.winner?.id == game.homeTeam?.id }
    var awayIsWinner: Bool { game.isFinished && game.winner?.id == game.awayTeam?.id }

    var body: some View {
        VStack(spacing: AppTheme.Spacing.small) {
            if game.isFinished {
                // Date + score
                VStack(spacing: 4) {
                    if let gameTime = game.gameTime {
                        Text(formatShortDate(gameTime))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(forceDarkText ? Color.black.opacity(0.5) : Color(white: 0.4))
                    }

                    HStack(spacing: 6) {
                        Text("\(game.homeScore ?? 0)")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(forceDarkText ? .black : (homeIsWinner ? AppTheme.Colors.accent : AppTheme.Colors.primaryText))
                            .frame(minWidth: 30)

                        Text("-")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(forceDarkText ? Color.black.opacity(0.5) : Color(white: 0.45))

                        Text("\(game.awayScore ?? 0)")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(forceDarkText ? .black : (awayIsWinner ? AppTheme.Colors.accent : AppTheme.Colors.primaryText))
                            .frame(minWidth: 30)
                    }
                    .fixedSize()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(forceDarkText ? Color.black.opacity(0.1) : Color(white: 0.06))
                            .stroke(forceDarkText ? Color.black.opacity(0.2) : Color(white: 0.2), lineWidth: 1)
                    )

                    Text("Final")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(forceDarkText ? Color.black.opacity(0.5) : Color(white: 0.4))
                }
            } else {
                // Date + time + VS
                if let gameTime = game.gameTime {
                    Text(formatFullDate(gameTime))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(forceDarkText ? Color.black.opacity(0.5) : Color(white: 0.4))
                    Text(formatTime(gameTime))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(forceDarkText ? .black : AppTheme.Colors.accent)
                }

                Text("VS")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(forceDarkText ? Color.black.opacity(0.5) : Color(white: 0.5))
            }
        }
    }

    private func formatShortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_MX")
        formatter.timeZone = AppConfig.DateTime.apiTimeZone
        formatter.dateFormat = "dd MMM yy"
        return formatter.string(from: date)
    }

    private func formatFullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_MX")
        formatter.timeZone = AppConfig.DateTime.apiTimeZone
        formatter.dateFormat = "dd MMMM yyyy"
        return formatter.string(from: date).capitalized
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = AppConfig.DateTime.apiTimeZone
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
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
