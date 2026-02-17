//
//  GamesListView.swift
//  Brackets
//
//  Created by Humberto on 16/02/26.
//

import SwiftUI

enum GameFilter: String, CaseIterable {
    case all = "All"
    case upcoming = "Upcoming"
    case completed = "Completed"
}

struct GamesListView: View {
    let tournament: Tournament
    @State private var gamesResponse: GamesResponse?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedFilter: GameFilter = .all
    
    var filteredGames: [GamesResponse.DateGroup] {
        guard let gamesResponse = gamesResponse else { return [] }
        
        switch selectedFilter {
        case .all:
            return gamesResponse.games
        case .upcoming:
            return gamesResponse.games.map { dateGroup in
                GamesResponse.DateGroup(
                    date: dateGroup.date,
                    games: dateGroup.games.filter { !$0.isFinished }
                )
            }.filter { !$0.games.isEmpty }
        case .completed:
            return gamesResponse.games.map { dateGroup in
                GamesResponse.DateGroup(
                    date: dateGroup.date,
                    games: dateGroup.games.filter { $0.isFinished }
                )
            }.filter { !$0.games.isEmpty }
        }
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
                                                GameCard(game: game)
                                                    .padding(.horizontal, AppTheme.Layout.screenPadding)
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
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        if let date = formatter.date(from: dateString) {
            formatter.dateFormat = "MMMM dd, yyyy"
            return formatter.string(from: date)
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
    
    var body: some View {
        VStack(spacing: AppTheme.Spacing.standard) {
            HStack(spacing: AppTheme.Spacing.large) {
                // Home Team
                TeamSection(
                    teamName: game.homeTeam?.name ?? "TBD",
                    initials: getInitials(game.homeTeam?.name ?? "TBD"),
                    isWinner: game.isFinished && game.winner?.id == game.homeTeam?.id
                )
                .frame(maxWidth: .infinity)
                
                // Center: Score or VS with time
                CenterSection(game: game)
                    .frame(width: 130)
                
                // Away Team
                TeamSection(
                    teamName: game.awayTeam?.name ?? "TBD",
                    initials: getInitials(game.awayTeam?.name ?? "TBD"),
                    isWinner: game.isFinished && game.winner?.id == game.awayTeam?.id
                )
                .frame(maxWidth: .infinity)
            }
            
            // Stadium/Location
            Text("City Stadium")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Color(white: 0.5))
        }
        .padding(.horizontal, AppTheme.Spacing.large)
        .padding(.vertical, AppTheme.Spacing.large)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large)
                .fill(Color(white: 0.1))
                .stroke(Color(white: 1.0).opacity(0.18), lineWidth: 1)
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
    
    var body: some View {
        VStack(spacing: AppTheme.Spacing.small) {
            // Team circle with initials
            ZStack {
                Circle()
                    .fill(isWinner ? AppTheme.Colors.accent : Color(white: 0.15))
                    .frame(width: 60, height: 60)
                
                // Winner ring
                if isWinner {
                    Circle()
                        .stroke(AppTheme.Colors.accent, lineWidth: 2)
                        .frame(width: 68, height: 68)
                }
                
                Text(initials)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(isWinner ? AppTheme.Colors.accentText : AppTheme.Colors.primaryText)
            }
            
            // Team Name
            Text(teamName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.primaryText)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
    }
}

/// Center section with score or time
struct CenterSection: View {
    let game: Game
    
    var homeIsWinner: Bool { game.isFinished && game.winner?.id == game.homeTeam?.id }
    var awayIsWinner: Bool { game.isFinished && game.winner?.id == game.awayTeam?.id }
    
    var body: some View {
        VStack(spacing: AppTheme.Spacing.small) {
            if game.isFinished {
                // Single enclosure box with both scores
                VStack(spacing: 4) {
                    HStack(spacing: 8) {
                        Text("\(game.homeScore ?? 0)")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(homeIsWinner ? AppTheme.Colors.accent : AppTheme.Colors.primaryText)
                        
                        Text("-")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(Color(white: 0.45))
                        
                        Text("\(game.awayScore ?? 0)")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(awayIsWinner ? AppTheme.Colors.accent : AppTheme.Colors.primaryText)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(white: 0.06))
                            .stroke(Color(white: 0.2), lineWidth: 1)
                    )
                    
                    Text("Final")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(white: 0.4))
                }
            } else {
                // Show VS and time
                Text("VS")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color(white: 0.5))
                
                if let gameTime = game.gameTime {
                    Text(formatTime(gameTime))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppTheme.Colors.accent)
                }
            }
        }
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
