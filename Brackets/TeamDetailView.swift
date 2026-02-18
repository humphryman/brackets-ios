//
//  TeamDetailView.swift
//  Brackets
//

import SwiftUI

enum TeamDetailTab: String, CaseIterable {
    case games = "Games"
    case players = "Players"
    case stats = "Stats"

    var icon: String {
        switch self {
        case .games: return "sportscourt"
        case .players: return "person.3"
        case .stats: return "chart.bar"
        }
    }
}

struct TeamDetailView: View {
    let standing: TeamStanding
    let tournamentId: Int
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: TeamDetailTab = .games
    @Namespace private var tabAnimation
    @State private var teamSeason: TeamSeasonDetail?
    @State private var isLoading = false
    @State private var errorMessage: String?

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
                    .zIndex(1)

                    Text(standing.teamName)
                        .font(AppTheme.Typography.largeTitle)
                        .foregroundStyle(AppTheme.Colors.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Spacer()
                }
                .padding(.horizontal, AppTheme.Layout.extraLarge)
                .padding(.top, AppTheme.Layout.large)
                .padding(.bottom, AppTheme.Layout.itemSpacing)
                .zIndex(1)

                VStack(spacing: AppTheme.Spacing.large) {
                    teamHeroCard
                    tabSelector
                }
                .padding(.horizontal, AppTheme.Layout.screenPadding)

                selectedTabContent
                    .padding(.top, AppTheme.Spacing.large)
                    .frame(maxHeight: .infinity)
            }
        }
        .navigationBarHidden(true)
        .task {
            await loadTeamSeason()
        }
    }

    // MARK: - Data Loading

    private func loadTeamSeason() async {
        isLoading = true
        errorMessage = nil
        do {
            teamSeason = try await APIService.shared.fetchTeamSeason(teamSeasonId: standing.id)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Tab Selector

    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(TeamDetailTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = tab
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 12, weight: .semibold))
                        Text(tab.rawValue)
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundStyle(selectedTab == tab ? AppTheme.Colors.accentText : Color(white: 0.5))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background {
                        if selectedTab == tab {
                            Capsule()
                                .fill(AppTheme.Colors.accent)
                                .matchedGeometryEffect(id: "teamTab", in: tabAnimation)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            Capsule()
                .fill(Color(white: 0.18))
        )
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var selectedTabContent: some View {
        if isLoading {
            AppTheme.LoadingView(message: "Loading team data...")
        } else if let errorMessage = errorMessage {
            AppTheme.ErrorView(message: errorMessage) {
                Task {
                    await loadTeamSeason()
                }
            }
        } else {
            switch selectedTab {
            case .games:
                TeamGamesTabView(games: teamSeason?.games ?? [], tournamentId: tournamentId)
            case .players:
                TeamPlayersTabView(players: teamSeason?.playerSeasons ?? [])
            case .stats:
                TeamStatsTabView()
            }
        }
    }

    // MARK: - Team Hero Card

    private var teamHeroCard: some View {
        ZStack(alignment: .bottom) {
            // Background team image
            if let imageURL = standing.fullImageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 200)
                            .clipped()
                    default:
                        placeholderBackground
                    }
                }
            } else {
                placeholderBackground
            }

            // Gradient overlay for readability
            LinearGradient(
                colors: [.clear, Color.black.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 120)

            // Team name overlay (top-left)
            VStack {
                HStack {
                    Text(standing.teamName)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(AppTheme.Colors.accent)
                        .shadow(color: .black.opacity(0.6), radius: 4, x: 0, y: 2)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                Spacer()
            }

            // Bottom bar overlay with wins / losses
            HStack(spacing: 24) {
                VStack(spacing: 4) {
                    Text("\(standing.wins)")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(AppTheme.Colors.accent)
                    Text("Wins")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color(white: 0.6))
                }

                Rectangle()
                    .fill(Color(white: 0.4))
                    .frame(width: 1, height: 40)

                VStack(spacing: 4) {
                    Text("\(standing.losses)")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(Color.red)
                    Text("Losses")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color(white: 0.6))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.black.opacity(0.6))
        }
        .frame(height: 200)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large)
                .stroke(Color(white: 1.0).opacity(0.18), lineWidth: 1)
        )
    }

    private var placeholderBackground: some View {
        Rectangle()
            .fill(Color(white: 0.15))
            .frame(maxWidth: .infinity)
            .frame(height: 200)
            .overlay(
                Image(systemName: "sportscourt")
                    .font(.system(size: 48))
                    .foregroundStyle(Color(white: 0.3))
            )
    }
}

// MARK: - Games Tab

struct TeamGamesTabView: View {
    let games: [Game]
    let tournamentId: Int

    var body: some View {
        if games.isEmpty {
            AppTheme.EmptyStateView(
                icon: "sportscourt",
                message: "No games scheduled"
            )
        } else {
            ScrollView {
                VStack(spacing: AppTheme.Spacing.medium) {
                    ForEach(games) { game in
                        if game.isFinished {
                            NavigationLink {
                                GameResultView(game: game, tournamentId: tournamentId)
                            } label: {
                                GameCard(game: game)
                            }
                            .buttonStyle(.plain)
                        } else {
                            NavigationLink {
                                UpcomingGameView(game: game, tournamentId: tournamentId)
                            } label: {
                                GameCard(game: game)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, AppTheme.Layout.screenPadding)
                .padding(.bottom, AppTheme.Layout.large)
            }
        }
    }
}

// MARK: - Players Tab

struct TeamPlayersTabView: View {
    let players: [PlayerSeason]

    private let columns = [
        GridItem(.flexible(), spacing: AppTheme.Spacing.medium),
        GridItem(.flexible(), spacing: AppTheme.Spacing.medium)
    ]

    var body: some View {
        if players.isEmpty {
            AppTheme.EmptyStateView(
                icon: "person.3",
                message: "No players available"
            )
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: AppTheme.Spacing.medium) {
                    ForEach(players) { player in
                        playerCard(player: player)
                    }
                }
                .padding(.horizontal, AppTheme.Layout.screenPadding)
                .padding(.bottom, AppTheme.Layout.large)
            }
        }
    }

    @ViewBuilder
    private func playerCard(player: PlayerSeason) -> some View {
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
                        playerInitialsRect(firstName: player.firstName, lastName: player.lastName)
                    }
                }
            } else {
                playerInitialsRect(firstName: player.firstName, lastName: player.lastName)
            }

            // Name + Number row
            HStack(alignment: .top, spacing: 4) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(player.firstName)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AppTheme.Colors.primaryText)
                        .lineLimit(1)
                    Text(player.lastName)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AppTheme.Colors.primaryText)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                if let number = player.number, number > 0 {
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
    private func playerInitialsRect(firstName: String, lastName: String) -> some View {
        let initials = String(firstName.prefix(1) + lastName.prefix(1)).uppercased()
        Rectangle()
            .fill(Color(white: 0.22))
            .aspectRatio(1, contentMode: .fill)
            .overlay(
                Text(initials)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Color(white: 0.45))
            )
    }
}

// MARK: - Stats Tab (Placeholder)

struct TeamStatsTabView: View {
    var body: some View {
        VStack(spacing: AppTheme.Spacing.large) {
            Spacer()
            Image(systemName: "chart.bar")
                .font(.system(size: 40))
                .foregroundStyle(Color(white: 0.3))
            Text("Team Stats")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.secondaryText)
            Text("Coming soon")
                .font(.system(size: 13))
                .foregroundStyle(Color(white: 0.35))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
