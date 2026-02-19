//
//  PlayerDetailView.swift
//  Brackets
//

import SwiftUI

struct PlayerDetailView: View {
    let stat: PlayerStatEntry
    let tournamentId: Int
    @Environment(\.dismiss) private var dismiss
    @State private var detail: PlayerSeasonDetailResponse?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            AppTheme.Colors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                Group {
                    if isLoading {
                        AppTheme.LoadingView(message: "Loading player stats...")
                    } else if let error = errorMessage {
                        AppTheme.ErrorView(message: error) {
                            Task { await loadPlayerSeason() }
                        }
                    } else if let detail = detail {
                        playerContent(detail)
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
        .navigationBarHidden(true)
        .task { await loadPlayerSeason() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Button { dismiss() } label: {
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

            Text("Player Stats")
                .font(AppTheme.Typography.largeTitle)
                .foregroundStyle(AppTheme.Colors.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer()
        }
        .padding(.horizontal, AppTheme.Layout.extraLarge)
        .padding(.top, AppTheme.Layout.large)
        .padding(.bottom, AppTheme.Layout.itemSpacing)
    }

    // MARK: - Content

    private func playerContent(_ detail: PlayerSeasonDetailResponse) -> some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.large) {
                heroCard(detail)
                totalStatsCard(detail)
                if !detail.playerSeason.stats.isEmpty {
                    opponentStatsCard(detail)
                }
            }
            .padding(.horizontal, AppTheme.Layout.screenPadding)
            .padding(.bottom, AppTheme.Layout.large)
        }
    }

    // MARK: - Hero Card

    private func heroCard(_ detail: PlayerSeasonDetailResponse) -> some View {
        let info = detail.playerSeason
        let player = info.player

        return VStack(spacing: 16) {
            // Photo + Name
            HStack(alignment: .center, spacing: 16) {
                playerPhoto(player)
                    .frame(width: 72, height: 72)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(AppTheme.Colors.accent, lineWidth: 2))

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(player.firstName) \(player.lastName)")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(AppTheme.Colors.primaryText)
                        .lineLimit(1)

                    Text(info.team)
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }

                Spacer()
            }

            Divider().background(Color(white: 0.2))

            // Info row
            HStack(spacing: 0) {
                infoItem(value: info.number != nil ? "#\(info.number!)" : "-", label: "Número")
                Spacer()
                infoItem(value: formatDOB(player.dob), label: "Nacimiento")
                Spacer()
                infoItem(value: player.position ?? "-", label: "Posición")
                Spacer()
                infoItem(value: info.height ?? "-", label: "Estatura")
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large)
                .fill(Color(white: 0.08))
                .stroke(Color(white: 1.0).opacity(0.12), lineWidth: 1)
        )
    }

    private func infoItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(AppTheme.Colors.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.Colors.secondaryText)
        }
    }

    // MARK: - Total Stats Card

    private func totalStatsCard(_ detail: PlayerSeasonDetailResponse) -> some View {
        let info = detail.playerSeason
        let gamesPlayed = info.stats.count

        // Order: points first, then remaining active stats
        var orderedKeys: [String] = []
        if info.activeStats.contains("points") {
            orderedKeys.append("points")
        }
        for key in info.activeStats where key != "points" {
            orderedKeys.append(key)
        }

        return VStack(spacing: 16) {
            Text("Player Total Stats")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppTheme.Colors.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Green stat boxes — horizontal carousel
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    // First stat (points)
                    if let firstKey = orderedKeys.first {
                        statBox(
                            value: "\(totalForStat(firstKey, in: info.stats))",
                            label: detail.longNameStats[firstKey] ?? firstKey
                        )
                    }

                    // GP
                    statBox(value: "\(gamesPlayed)", label: "Partidos")

                    // Remaining stats
                    ForEach(Array(orderedKeys.dropFirst().enumerated()), id: \.offset) { _, key in
                        statBox(
                            value: "\(totalForStat(key, in: info.stats))",
                            label: detail.longNameStats[key] ?? key
                        )
                    }
                }
                .padding(.horizontal, 2)
            }

            // Per-game averages: PPG, APG, RPG
            if gamesPlayed > 0 {
                let perGameStats: [(key: String, label: String)] = [
                    ("points", "PPG"),
                    ("as", "APG"),
                    ("tr", "RPG")
                ]
                let available = perGameStats.filter { info.activeStats.contains($0.key) }

                if !available.isEmpty {
                    HStack(spacing: 0) {
                        ForEach(available, id: \.key) { stat in
                            let total = totalForStat(stat.key, in: info.stats)
                            let avg = Double(total) / Double(gamesPlayed)

                            VStack(spacing: 4) {
                                Text(String(format: "%.1f", avg))
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(AppTheme.Colors.primaryText)

                                Text(stat.label)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(AppTheme.Colors.secondaryText)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large)
                .fill(Color(white: 0.08))
                .stroke(Color(white: 1.0).opacity(0.12), lineWidth: 1)
        )
    }

    private func statBox(value: String, label: String) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AppTheme.Colors.accentText)

            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.accentText.opacity(0.7))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 8)
        .frame(width: 80, height: 68)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(AppTheme.Colors.accent)
        )
    }

    // MARK: - Stats vs Opponents

    private func opponentStatsCard(_ detail: PlayerSeasonDetailResponse) -> some View {
        let info = detail.playerSeason
        let statColumnWidth: CGFloat = 44
        let headerHeight: CGFloat = 36
        let rowHeight: CGFloat = 52

        return VStack(spacing: 16) {
            Text("Stats vs Opponents")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppTheme.Colors.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Table: fixed opponent column | scrollable stats column
            HStack(alignment: .top, spacing: 0) {
                // Fixed opponent column
                VStack(spacing: 0) {
                    // Header
                    Text("Opponent")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(white: 0.5))
                        .frame(height: headerHeight)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)

                    Divider().background(Color(white: 0.2))

                    // Opponent rows
                    ForEach(info.stats) { game in
                        VStack(spacing: 0) {
                            HStack(spacing: 8) {
                                opponentCircle(game)
                                    .frame(width: 32, height: 32)

                                Text(game.opponent)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(AppTheme.Colors.primaryText)
                                    .lineLimit(1)
                            }
                            .frame(height: rowHeight)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)

                            Divider().background(Color(white: 0.15))
                        }
                    }
                }
                .frame(width: 140)

                // Vertical separator
                Rectangle()
                    .fill(Color(white: 0.2))
                    .frame(width: 1)

                // Scrollable stats columns
                ScrollView(.horizontal, showsIndicators: true) {
                    VStack(spacing: 0) {
                        // Stat headers
                        HStack(spacing: 0) {
                            ForEach(info.activeStats, id: \.self) { key in
                                Text(detail.shortNameStats[key] ?? key.uppercased())
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color(white: 0.5))
                                    .frame(width: statColumnWidth, alignment: .center)
                            }
                        }
                        .frame(height: headerHeight)

                        Divider().background(Color(white: 0.2))

                        // Stat value rows
                        ForEach(info.stats) { game in
                            VStack(spacing: 0) {
                                HStack(spacing: 0) {
                                    ForEach(info.activeStats, id: \.self) { key in
                                        let value = game.dynamicStats[key].flatMap { $0 }
                                        Text(value != nil ? "\(value!)" : "-")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(AppTheme.Colors.primaryText)
                                            .frame(width: statColumnWidth, alignment: .center)
                                    }
                                }
                                .frame(height: rowHeight)

                                Divider().background(Color(white: 0.15))
                            }
                        }
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(white: 0.2), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large)
                .fill(Color(white: 0.08))
                .stroke(Color(white: 1.0).opacity(0.12), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func opponentCircle(_ game: PlayerSeasonGameStat) -> some View {
        if let imageURL = game.opponentFullImageURL, let url = URL(string: imageURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .clipShape(Circle())
                default:
                    opponentInitials(game.opponent)
                }
            }
        } else {
            opponentInitials(game.opponent)
        }
    }

    private func opponentInitials(_ name: String) -> some View {
        let initials = String(name.prefix(2)).uppercased()
        return Circle()
            .fill(AppTheme.Colors.accent)
            .overlay(
                Text(initials)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.Colors.accentText)
            )
    }

    // MARK: - Player Photo

    @ViewBuilder
    private func playerPhoto(_ player: Player) -> some View {
        if let picture = player.picture,
           let url = URL(string: picture.hasPrefix("http") ? picture : "\(APIConfig.baseURL)/\(picture)") {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    playerInitialsCircle(player)
                }
            }
        } else {
            playerInitialsCircle(player)
        }
    }

    private func playerInitialsCircle(_ player: Player) -> some View {
        let initials = String(player.firstName.prefix(1) + player.lastName.prefix(1)).uppercased()
        return Circle()
            .fill(AppTheme.Colors.accent.opacity(0.15))
            .overlay(
                Text(initials)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(AppTheme.Colors.accent)
            )
    }

    // MARK: - Helpers

    private func totalForStat(_ key: String, in stats: [PlayerSeasonGameStat]) -> Int {
        stats.reduce(0) { $0 + (($1.dynamicStats[key] ?? nil) ?? 0) }
    }

    private func formatDOB(_ dob: String?) -> String {
        guard let dob = dob else { return "-" }

        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd"
        inputFormatter.locale = Locale(identifier: "en_US_POSIX")

        guard let date = inputFormatter.date(from: dob) else { return dob }

        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "dd MMM yy"
        return outputFormatter.string(from: date)
    }

    // MARK: - Data Loading

    private func loadPlayerSeason() async {
        isLoading = true
        errorMessage = nil

        do {
            detail = try await APIService.shared.fetchPlayerSeason(playerSeasonId: stat.playerSeasonId)
            isLoading = false
        } catch {
            errorMessage = "Failed to load player stats"
            isLoading = false
            print("❌ Player season loading error: \(error)")
        }
    }
}
