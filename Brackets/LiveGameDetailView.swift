//
//  LiveGameDetailView.swift
//  Brackets
//

import SwiftUI

struct LiveGameDetailView: View {
    let game: Game
    let tournamentId: Int
    @Environment(\.dismiss) private var dismiss

    @State private var gameDetail: GameDetailResponse?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedTeamIndex: Int = 0
    @State private var refreshTimer: Timer?
    @State private var previousStats: [Int: [String: Int?]] = [:] // playerId -> stats snapshot
    @State private var previousStarters: [Int: Bool] = [:] // playerId -> was starter
    @State private var pulsingCells: Set<String> = [] // "playerId-statKey"
    @State private var highlightedPlayers: Set<Int> = [] // player IDs with recent stat changes
    @State private var rosterGlowGreen: Set<Int> = [] // players added to starters
    @State private var rosterGlowRed: Set<Int> = [] // players moved to bench

    var body: some View {
        ZStack {
            AppTheme.Colors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                ZStack {
                    Text("En Vivo")
                        .font(AppTheme.Typography.headline)
                        .foregroundStyle(Color.red)

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

                if isLoading && gameDetail == nil {
                    Spacer()
                    ProgressView()
                        .tint(Color.red)
                        .scaleEffect(1.2)
                    Spacer()
                } else if let errorMessage = errorMessage, gameDetail == nil {
                    Spacer()
                    AppTheme.ErrorView(message: errorMessage) {
                        Task { await loadGameDetail() }
                    }
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: AppTheme.Spacing.large) {
                            // Live game card at top
                            LiveGameCard(game: game, detail: gameDetail, tournamentId: tournamentId)

                            // Player stats
                            if let detail = gameDetail {
                                livePlayerStatsCard(detail: detail)
                            }
                        }
                        .padding(.horizontal, AppTheme.Layout.screenPadding)
                        .padding(.bottom, AppTheme.Layout.large)
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .task {
            await loadGameDetail()
            startRefreshTimer()
        }
        .onDisappear {
            stopRefreshTimer()
        }
    }

    // MARK: - Data Loading

    private func loadGameDetail() async {
        if gameDetail == nil {
            isLoading = true
        }
        errorMessage = nil

        do {
            let detail = try await APIService.shared.fetchGameDetail(
                tournamentId: tournamentId,
                gameId: game.id
            )
            await MainActor.run {
                detectStatChanges(newDetail: detail)
                gameDetail = detail
                isLoading = false
            }
        } catch {
            await MainActor.run {
                if gameDetail == nil {
                    errorMessage = error.localizedDescription
                }
                isLoading = false
            }
        }
    }

    private func startRefreshTimer() {
        stopRefreshTimer()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
            Task { await loadGameDetail() }
        }
    }

    private func stopRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    // MARK: - Stat Change Detection

    private func detectStatChanges(newDetail: GameDetailResponse) {
        let teams = newDetail.game.teamStats ?? []
        var newPulses: Set<String> = []
        var changedPlayers: Set<Int> = []
        var newGlowGreen: Set<Int> = []
        var newGlowRed: Set<Int> = []

        for team in teams {
            for player in (team.playerStats ?? []) where !player.isTeamEntry {
                // Stat changes
                let oldStats = previousStats[player.id]
                if let oldStats {
                    for (key, newValue) in player.dynamicStats {
                        let oldValue = oldStats[key] ?? nil
                        if newValue != oldValue {
                            newPulses.insert("\(player.id)-\(key)")
                            changedPlayers.insert(player.id)
                        }
                    }
                }
                previousStats[player.id] = player.dynamicStats

                // Roster changes
                if let wasStarter = previousStarters[player.id] {
                    if player.starter && !wasStarter {
                        newGlowGreen.insert(player.id)
                    } else if !player.starter && wasStarter {
                        newGlowRed.insert(player.id)
                    }
                }
                previousStarters[player.id] = player.starter
            }
        }

        if !newPulses.isEmpty {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                pulsingCells = newPulses
                highlightedPlayers = changedPlayers
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeOut(duration: 0.5)) {
                    pulsingCells = []
                    highlightedPlayers = []
                }
            }
        }

        if !newGlowGreen.isEmpty || !newGlowRed.isEmpty {
            withAnimation(.easeIn(duration: 0.3)) {
                rosterGlowGreen = newGlowGreen
                rosterGlowRed = newGlowRed
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeOut(duration: 0.5)) {
                    rosterGlowGreen = []
                    rosterGlowRed = []
                }
            }
        }
    }

    // MARK: - Live Player Stats Card

    @ViewBuilder
    private func livePlayerStatsCard(detail: GameDetailResponse) -> some View {
        let teams = detail.game.teamStats ?? []
        let activeStats = detail.game.activeStats ?? []

        if teams.count >= 2 {
            let safeIndex = min(selectedTeamIndex, teams.count - 1)
            let selectedTeam = teams[safeIndex]
            let allPlayers = (selectedTeam.playerStats ?? []).filter { !$0.isTeamEntry }
            let starters = allPlayers.filter { $0.starter }
            let bench = allPlayers.filter { !$0.starter }

            VStack(spacing: AppTheme.Spacing.large) {
                // Title
                Text("Stats en Vivo")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppTheme.Colors.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Team selector
                HStack(spacing: 0) {
                    ForEach(Array(teams.enumerated()), id: \.element.id) { index, team in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedTeamIndex = index
                            }
                        } label: {
                            Text(team.teamName)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(selectedTeamIndex == index ? AppTheme.Colors.accentText : Color(white: 0.5))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    Capsule()
                                        .fill(selectedTeamIndex == index ? AppTheme.Colors.accent : Color.clear)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3)
                .background(
                    Capsule()
                        .fill(Color(white: 0.18))
                )

                // Starters table
                if !starters.isEmpty {
                    liveStatsTable(
                        title: "En Cancha",
                        players: starters,
                        activeStats: activeStats,
                        detail: detail,
                        sectionType: .starters
                    )
                }

                // Bench table
                if !bench.isEmpty {
                    liveStatsTable(
                        title: "Banca",
                        players: bench,
                        activeStats: activeStats,
                        detail: detail,
                        sectionType: .bench
                    )
                }
            }
            .padding(AppTheme.Layout.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large)
                    .fill(Color(white: 0.1))
                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
            )
        }
    }

    private enum RosterSection {
        case starters, bench
    }

    @ViewBuilder
    private func liveStatsTable(title: String, players: [PlayerGameStat], activeStats: [String], detail: GameDetailResponse, sectionType: RosterSection) -> some View {
        let rowHeight: CGFloat = 50
        let headerHeight: CGFloat = 38
        let minStatWidth: CGFloat = 56
        let needsScroll = CGFloat(activeStats.count) * minStatWidth > 200

        VStack(spacing: 8) {
            // Section title
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(sectionType == .starters ? AppTheme.Colors.accent : Color(white: 0.5))
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 0) {
                // Fixed player name column
                VStack(spacing: 0) {
                    Text("JUGADOR")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(white: 0.45))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(height: headerHeight)
                        .padding(.leading, 12)

                    Divider().background(Color(white: 0.2))

                    ForEach(Array(players.enumerated()), id: \.element.id) { index, player in
                        if let psId = player.playerSeasonId {
                            NavigationLink {
                                PlayerDetailView(playerSeasonId: psId, tournamentId: tournamentId)
                            } label: {
                                livePlayerRow(
                                    player: player,
                                    index: index,
                                    rowHeight: rowHeight,
                                    isHighlighted: highlightedPlayers.contains(player.id),
                                    rosterGlow: rosterGlowColor(for: player.id)
                                )
                            }
                            .buttonStyle(.plain)
                        } else {
                            livePlayerRow(
                                player: player,
                                index: index,
                                rowHeight: rowHeight,
                                isHighlighted: highlightedPlayers.contains(player.id),
                                rosterGlow: rosterGlowColor(for: player.id)
                            )
                        }
                    }
                }
                .frame(width: 150)

                // Stats columns
                let statsContent = VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        ForEach(activeStats, id: \.self) { statKey in
                            Text(detail.shortNameStats[statKey] ?? statKey.uppercased())
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color(white: 0.45))
                                .frame(minWidth: minStatWidth, maxWidth: .infinity)
                        }
                    }
                    .frame(height: headerHeight)

                    Divider().background(Color(white: 0.2))

                    ForEach(Array(players.enumerated()), id: \.element.id) { index, player in
                        HStack(spacing: 0) {
                            ForEach(activeStats, id: \.self) { statKey in
                                let value = player.dynamicStats[statKey] ?? nil
                                let cellKey = "\(player.id)-\(statKey)"
                                let isPulsing = pulsingCells.contains(cellKey)

                                Text(value.map { "\($0)" } ?? "-")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(player.played ? AppTheme.Colors.primaryText : Color(white: 0.3))
                                    .frame(minWidth: minStatWidth, maxWidth: .infinity)
                                    .scaleEffect(isPulsing ? 1.3 : 1.0)
                            }
                        }
                        .frame(height: rowHeight)
                        .opacity(player.played ? 1.0 : 0.5)
                        .background(rowBackground(for: player, index: index))
                    }
                }

                if needsScroll {
                    ScrollView(.horizontal, showsIndicators: true) {
                        statsContent
                    }
                } else {
                    statsContent
                }
            }
        }
    }

    private func rowBackground(for player: PlayerGameStat, index: Int) -> Color {
        if rosterGlowGreen.contains(player.id) {
            return AppTheme.Colors.accent.opacity(0.15)
        }
        if rosterGlowRed.contains(player.id) {
            return Color.red.opacity(0.15)
        }
        if highlightedPlayers.contains(player.id) {
            return AppTheme.Colors.accent.opacity(0.1)
        }
        return index % 2 == 0 ? Color(white: 0.14) : Color.clear
    }

    private func rosterGlowColor(for playerId: Int) -> Color? {
        if rosterGlowGreen.contains(playerId) {
            return AppTheme.Colors.accent.opacity(0.15)
        }
        if rosterGlowRed.contains(playerId) {
            return Color.red.opacity(0.15)
        }
        return nil
    }

    // MARK: - Player Row

    @ViewBuilder
    private func livePlayerRow(player: PlayerGameStat, index: Int, rowHeight: CGFloat, isHighlighted: Bool = false, rosterGlow: Color? = nil) -> some View {
        HStack(spacing: 6) {
            if let number = player.playerNumber, number > 0 {
                Text("#\(number)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color(white: 0.4))
                    .frame(width: 30, alignment: .center)
            } else {
                Spacer().frame(width: 28)
            }
            livePlayerAvatar(player: player, size: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text(player.playerFirstName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(player.played ? AppTheme.Colors.primaryText : Color(white: 0.3))
                    .lineLimit(1)
                Text(player.playerLastName)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(player.played ? Color(white: 0.5) : Color(white: 0.25))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: rowHeight)
        .padding(.leading, 6)
        .opacity(player.played ? 1.0 : 0.5)
        .background(rosterGlow ?? (isHighlighted ? AppTheme.Colors.accent.opacity(0.1) : (index % 2 == 0 ? Color(white: 0.14) : Color.clear)))
    }

    // MARK: - Player Avatar

    @ViewBuilder
    private func livePlayerAvatar(player: PlayerGameStat, size: CGFloat) -> some View {
        if let imageURL = player.fullImageURL, let url = URL(string: imageURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                default:
                    livePlayerInitials(name: player.playerName, size: size)
                }
            }
        } else {
            livePlayerInitials(name: player.playerName, size: size)
        }
    }

    private func livePlayerInitials(name: String, size: CGFloat) -> some View {
        let words = name.split(separator: " ")
        let initials = words.count >= 2
            ? String(words[0].prefix(1) + words[1].prefix(1)).uppercased()
            : String(name.prefix(2)).uppercased()
        return Circle()
            .fill(Color(white: 0.15))
            .frame(width: size, height: size)
            .overlay(
                Text(initials)
                    .font(.system(size: size * 0.35, weight: .bold))
                    .foregroundStyle(AppTheme.Colors.primaryText)
            )
            .overlay(Circle().stroke(Color(white: 0.25), lineWidth: 1))
    }
}
