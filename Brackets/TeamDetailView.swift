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
                TeamStatsTabView(statLeaders: teamSeason?.statLeaders ?? [:], categories: teamSeason?.statCategories ?? [])
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

// MARK: - Stats Tab

struct TeamStatsTabView: View {
    let statLeaders: [String: [StatLeaderEntry]]
    let categories: [String]
    @State private var selectedStatIndex: Int = 0

    var body: some View {
        if categories.isEmpty {
            AppTheme.EmptyStateView(
                icon: "chart.bar",
                message: "No stats available"
            )
        } else {
            let safeStatIndex = min(selectedStatIndex, categories.count - 1)
            let currentCategory = categories[safeStatIndex]
            let leaders = statLeaders[currentCategory] ?? []

            ScrollView {
                VStack(spacing: AppTheme.Spacing.large) {
                    statLeadersCard(
                        category: currentCategory,
                        leaders: leaders,
                        safeStatIndex: safeStatIndex
                    )
                }
                .padding(.horizontal, AppTheme.Layout.screenPadding)
                .padding(.bottom, AppTheme.Layout.large)
            }
        }
    }

    // MARK: - Stat Leaders Card

    @ViewBuilder
    private func statLeadersCard(category: String, leaders: [StatLeaderEntry], safeStatIndex: Int) -> some View {
        VStack(spacing: AppTheme.Spacing.large) {
            // Title
            Text("Team Stats Leaders")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppTheme.Colors.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Category selector with arrows
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedStatIndex = (selectedStatIndex - 1 + categories.count) % categories.count
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.primaryText)
                        .frame(width: 36, height: 36)
                        .background(Circle().stroke(Color(white: 0.25), lineWidth: 1))
                }

                Spacer()

                VStack(spacing: 2) {
                    Text(category)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppTheme.Colors.accent)
                    Text("TEAM LEADERS")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color(white: 0.45))
                }

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedStatIndex = (selectedStatIndex + 1) % categories.count
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.primaryText)
                        .frame(width: 36, height: 36)
                        .background(Circle().stroke(Color(white: 0.25), lineWidth: 1))
                }
            }
            .padding(.horizontal, 4)

            Divider().background(Color(white: 0.2))

            // Leaders content or empty state
            if leaders.isEmpty {
                Text("No info for this stat.")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppTheme.Spacing.huge)
            } else {
                // #1 Leader - hero layout
                if let top = leaders.first {
                    HStack(alignment: .center, spacing: 12) {
                        leaderHeroImage(entry: top, size: 120)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(top.firstName)
                                .font(.system(size: 16))
                                .foregroundStyle(AppTheme.Colors.primaryText)
                            Text(top.lastName)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(AppTheme.Colors.primaryText)
                        }

                        Spacer(minLength: 0)

                        VStack(spacing: 2) {
                            Text("\(top.total)")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(AppTheme.Colors.accentText)
                            Text(category)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(AppTheme.Colors.accentText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(width: 52, height: 52)
                        .background(
                            Circle()
                                .fill(AppTheme.Colors.accent)
                        )
                    }
                }

                // #2-5 runners up
                let runnersUp = Array(leaders.dropFirst().prefix(4))
                ForEach(runnersUp) { entry in
                    HStack(spacing: 12) {
                        leaderAvatarCircle(entry: entry, size: 44)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.firstName)
                                .font(.system(size: 12))
                                .foregroundStyle(AppTheme.Colors.secondaryText)
                            Text(entry.lastName)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(AppTheme.Colors.primaryText)
                        }

                        Spacer()

                        HStack(spacing: 6) {
                            Text(category)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color(white: 0.4))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color(white: 0.18))
                                )
                            Text("\(entry.total)")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(AppTheme.Colors.accent)
                        }
                    }
                }
            }

            // Page indicator dots
            HStack(spacing: 6) {
                ForEach(Array(categories.enumerated()), id: \.element) { index, _ in
                    Capsule()
                        .fill(index == safeStatIndex ? AppTheme.Colors.accent : Color(white: 0.25))
                        .frame(width: index == safeStatIndex ? 20 : 8, height: 6)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(AppTheme.Layout.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large)
                .fill(Color(white: 0.1))
                .stroke(Color(white: 1.0).opacity(0.18), lineWidth: 1)
        )
        .gesture(
            DragGesture(minimumDistance: 30, coordinateSpace: .local)
                .onEnded { value in
                    let horizontal = value.translation.width
                    if horizontal < -30 {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedStatIndex = (selectedStatIndex + 1) % categories.count
                        }
                    } else if horizontal > 30 {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedStatIndex = (selectedStatIndex - 1 + categories.count) % categories.count
                        }
                    }
                }
        )
    }

    // MARK: - Image Helpers

    @ViewBuilder
    private func leaderHeroImage(entry: StatLeaderEntry, size: CGFloat) -> some View {
        if let imageURL = entry.fullImageURL, let url = URL(string: imageURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium))
                default:
                    heroInitialsRect(firstName: entry.firstName, lastName: entry.lastName, size: size)
                }
            }
        } else {
            heroInitialsRect(firstName: entry.firstName, lastName: entry.lastName, size: size)
        }
    }

    @ViewBuilder
    private func leaderAvatarCircle(entry: StatLeaderEntry, size: CGFloat) -> some View {
        if let imageURL = entry.fullImageURL, let url = URL(string: imageURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                default:
                    initialsCircle(firstName: entry.firstName, lastName: entry.lastName, size: size)
                }
            }
        } else {
            initialsCircle(firstName: entry.firstName, lastName: entry.lastName, size: size)
        }
    }

    @ViewBuilder
    private func heroInitialsRect(firstName: String, lastName: String, size: CGFloat) -> some View {
        let initials = String(firstName.prefix(1) + lastName.prefix(1)).uppercased()
        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
            .fill(Color(white: 0.18))
            .frame(width: size, height: size)
            .overlay(
                Text(initials)
                    .font(.system(size: size * 0.25, weight: .bold))
                    .foregroundStyle(Color(white: 0.4))
            )
    }

    @ViewBuilder
    private func initialsCircle(firstName: String, lastName: String, size: CGFloat) -> some View {
        let initials = String(firstName.prefix(1) + lastName.prefix(1)).uppercased()
        Circle()
            .fill(Color(white: 0.15))
            .frame(width: size, height: size)
            .overlay(
                Text(initials)
                    .font(.system(size: size * 0.3, weight: .bold))
                    .foregroundStyle(AppTheme.Colors.primaryText)
            )
            .overlay(Circle().stroke(Color(white: 0.25), lineWidth: 1))
    }
}
