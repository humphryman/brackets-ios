//
//  GamesListView.swift
//  Brackets
//
//  Created by Humberto on 16/02/26.
//

import SwiftUI

enum GameFilter: String, CaseIterable {
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
    
    var filteredGames: [GamesResponse.DateGroup] {
        guard let gamesResponse = gamesResponse else { return [] }

        let groups: [GamesResponse.DateGroup]
        switch selectedFilter {
        case .all:
            groups = gamesResponse.games
        case .upcoming:
            groups = gamesResponse.games.map { dateGroup in
                GamesResponse.DateGroup(
                    date: dateGroup.date,
                    games: dateGroup.games.filter { !$0.isFinished }
                )
            }.filter { !$0.games.isEmpty }
        case .completed:
            groups = gamesResponse.games.map { dateGroup in
                GamesResponse.DateGroup(
                    date: dateGroup.date,
                    games: dateGroup.games.filter { $0.isFinished }
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
                if filteredGames.isEmpty {
                    AppTheme.EmptyStateView(
                        icon: "sportscourt",
                        message: selectedFilter == .all ? "No games scheduled" : "No \(selectedFilter.rawValue.lowercased()) games"
                    )
                } else {
                    VStack(spacing: 0) {
                        // Filter Buttons
                        GameFilterView(selectedFilter: $selectedFilter)
                            .padding(.horizontal, AppTheme.Layout.screenPadding)
                            .padding(.top, AppTheme.Spacing.medium)
                            .padding(.bottom, AppTheme.Spacing.large)
                        
                        // Games List
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
                                            if game.isFinished {
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
                                }
                            }
                            .padding(.bottom, AppTheme.Layout.large)
                        }
                    }
                }
            } else {
                AppTheme.EmptyStateView(
                    icon: "sportscourt",
                    message: "No games available"
                )
            }
        }
        .task {
            await loadGames()
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
    
    private func formatDateHeader(_ dateString: String) -> String {
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"

        if let date = parser.date(from: dateString) {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "es_MX")
            formatter.dateFormat = "MMMM dd, yyyy"
            return formatter.string(from: date).capitalized
        }

        return dateString
    }
}

/// Filter buttons at the top (All, Upcoming, Completed)
struct GameFilterView: View {
    @Binding var selectedFilter: GameFilter
    
    var body: some View {
        HStack(spacing: AppTheme.Spacing.small) {
            ForEach(GameFilter.allCases, id: \.self) { filter in
                FilterButton(
                    title: filter.rawValue,
                    isSelected: selectedFilter == filter
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedFilter = filter
                    }
                }
            }
            
            Spacer()
        }
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
    
    private var isSemifinal: Bool {
        game.stage?.lowercased().contains("semifinal") == true
    }

    private var isFinal: Bool {
        guard let stage = game.stage?.lowercased() else { return false }
        return stage.contains("final") && !stage.contains("semifinal")
    }

    private var stageBadgeText: String? {
        if isSemifinal { return "Semifinal" }
        if isFinal { return "Final" }
        return nil
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: AppTheme.Spacing.standard) {
                if stageBadgeText != nil {
                    Spacer().frame(height: 9)
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
                        .frame(width: 130)

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
            }
        }
        .padding(.horizontal, AppTheme.Spacing.large)
        .padding(.vertical, AppTheme.Spacing.large)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large)
                .fill(isFinal ? AppTheme.Colors.accent : Color(white: 0.1))
                .stroke(isSemifinal ? AppTheme.Colors.accent.opacity(0.6) : Color(white: 1.0).opacity(isFinal ? 0 : 0.18), lineWidth: isSemifinal ? 1.5 : 1)
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

                // Winner ring
                if isWinner {
                    Circle()
                        .stroke(AppTheme.Colors.accent, lineWidth: 2)
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
            .fill(isWinner ? AppTheme.Colors.accent : Color(white: 0.15))
            .frame(width: 60, height: 60)
            .overlay(
                Text(initials)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(isWinner ? AppTheme.Colors.accentText : AppTheme.Colors.primaryText)
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

                    HStack(spacing: 8) {
                        Text("\(game.homeScore ?? 0)")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(forceDarkText ? .black : (homeIsWinner ? AppTheme.Colors.accent : AppTheme.Colors.primaryText))

                        Text("-")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(forceDarkText ? Color.black.opacity(0.5) : Color(white: 0.45))

                        Text("\(game.awayScore ?? 0)")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(forceDarkText ? .black : (awayIsWinner ? AppTheme.Colors.accent : AppTheme.Colors.primaryText))
                    }
                    .padding(.horizontal, 24)
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
                    Text(formatShortDate(gameTime))
                        .font(.system(size: 11, weight: .semibold))
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
        formatter.dateFormat = "dd MMM yy"
        return formatter.string(from: date)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
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
