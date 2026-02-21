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
        case .games: return "basketball"
        case .players: return "person.3"
        case .stats: return "chart.bar"
        }
    }
}

struct TeamDetailView: View {
    let standing: TeamStanding
    let tournamentId: Int
    var rank: Int = 0
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: TeamDetailTab = .games
    @Namespace private var tabAnimation
    @State private var teamSeason: TeamSeasonDetail?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            ZStack {
                AppTheme.Colors.background

                // Radial glow in top-right corner
                RadialGradient(
                    colors: [
                        AppTheme.Colors.accentGradient.opacity(0.20),
                        AppTheme.Colors.accentGradient.opacity(0.19),
                        AppTheme.Colors.accentGradient.opacity(0.15),
                        AppTheme.Colors.accentGradient.opacity(0.11),
                        AppTheme.Colors.accentGradient.opacity(0.08),
                        AppTheme.Colors.accentGradient.opacity(0.04),
                        AppTheme.Colors.accentGradient.opacity(0.01),
                        .clear
                    ],
                    center: .topTrailing,
                    startRadius: 0,
                    endRadius: 550
                )
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                ZStack {
                    // Centered title
                    Text("Team Details")
                        .font(AppTheme.Typography.headline)
                        .foregroundStyle(AppTheme.Colors.primaryText)

                    // Back button — leading
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Circle()
                                .fill(Color.white.opacity(0.08))
                                .frame(width: 36, height: 36)
                                .overlay {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(AppTheme.Colors.primaryText)
                                }
                        }

                        Spacer()
                    }
                }
                .padding(.horizontal, AppTheme.Layout.screenPadding)
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
                TeamPlayersTabView(players: teamSeason?.playerSeasons ?? [], tournamentId: tournamentId)
            case .stats:
                TeamStatsTabView(statLeaders: teamSeason?.nonEmptyStatLeaders ?? [])
            }
        }
    }

    // MARK: - Team Hero Card

    private var teamHeroCard: some View {
        VStack(spacing: 16) {
            // Logo + Name
            HStack(alignment: .center, spacing: 16) {
                teamLogoCircle

                VStack(alignment: .leading, spacing: 4) {
                    Text(standing.teamName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(AppTheme.Colors.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                Spacer()
            }

            Divider().background(Color(white: 0.2))

            // Place, Wins, Losses row
            HStack(spacing: 0) {
                infoItem(value: rank > 0 ? "#\(rank)" : "-", label: "Place")
                Spacer()
                infoItem(value: "\(standing.wins)", label: "Wins")
                Spacer()
                infoItem(value: "\(standing.losses)", label: "Losses")
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large)
                .fill(Color(white: 0.08).opacity(0.5))
                .stroke(Color(white: 1.0).opacity(0.10), lineWidth: 1)
        )
    }

    private func infoItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(AppTheme.Colors.primaryText)

            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.Colors.secondaryText)
        }
    }

    @ViewBuilder
    private var teamLogoCircle: some View {
        if let imageURL = standing.fullImageURL, let url = URL(string: imageURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 64, height: 64)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(AppTheme.Colors.accent, lineWidth: 2))
                default:
                    teamInitialsCircle
                }
            }
        } else {
            teamInitialsCircle
        }
    }

    private var teamInitialsCircle: some View {
        let words = standing.teamName.split(separator: " ")
        let initials: String = if words.count >= 2 {
            String(words[0].prefix(1) + words[1].prefix(1)).uppercased()
        } else {
            String(standing.teamName.prefix(3)).uppercased()
        }
        return Circle()
            .fill(AppTheme.Colors.accent.opacity(0.15))
            .frame(width: 64, height: 64)
            .overlay(
                Text(initials)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AppTheme.Colors.accent)
            )
            .overlay(Circle().stroke(AppTheme.Colors.accent, lineWidth: 2))
    }
}

// MARK: - Games Tab

struct TeamGamesTabView: View {
    let games: [Game]
    let tournamentId: Int

    var body: some View {
        if games.isEmpty {
            AppTheme.EmptyStateView(
                icon: "basketball",
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
    let tournamentId: Int

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
                        NavigationLink {
                            PlayerDetailView(playerSeasonId: player.id, tournamentId: tournamentId)
                        } label: {
                            playerCard(player: player)
                        }
                        .buttonStyle(.plain)
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
    let statLeaders: [StatLeaderCategory]
    @State private var selectedStatIndex: Int = 0

    var body: some View {
        if statLeaders.isEmpty {
            AppTheme.EmptyStateView(
                icon: "chart.bar",
                message: "No stats available"
            )
        } else {
            let safeIndex = min(selectedStatIndex, statLeaders.count - 1)
            let current = statLeaders[safeIndex]

            ScrollView {
                VStack(spacing: AppTheme.Spacing.large) {
                    statLeadersCard(category: current, safeStatIndex: safeIndex)
                }
                .padding(.horizontal, AppTheme.Layout.screenPadding)
                .padding(.bottom, AppTheme.Layout.large)
            }
        }
    }

    // MARK: - Stat Leaders Card

    @ViewBuilder
    private func statLeadersCard(category: StatLeaderCategory, safeStatIndex: Int) -> some View {
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
                        selectedStatIndex = (selectedStatIndex - 1 + statLeaders.count) % statLeaders.count
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
                    Text(category.longName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppTheme.Colors.accent)
                    Text("TEAM LEADERS")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color(white: 0.45))
                }

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedStatIndex = (selectedStatIndex + 1) % statLeaders.count
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

            // #1 Leader - hero layout
            if let top = category.players.first {
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
                        Text(category.shortName)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(AppTheme.Colors.accentText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(width: 64, height: 64)
                    .background(
                        Circle()
                            .fill(AppTheme.Colors.accent)
                    )
                }
            }

            // #2-5 runners up
            let runnersUp = Array(category.players.dropFirst().prefix(4))
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
                        Text(category.shortName)
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

            // Page indicator dots
            HStack(spacing: 6) {
                ForEach(Array(statLeaders.enumerated()), id: \.element.id) { index, _ in
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
                            selectedStatIndex = (selectedStatIndex + 1) % statLeaders.count
                        }
                    } else if horizontal > 30 {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedStatIndex = (selectedStatIndex - 1 + statLeaders.count) % statLeaders.count
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
