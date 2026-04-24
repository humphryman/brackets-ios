//
//  StatsLeadersView.swift
//  Brackets
//
//  Created by Humberto on 16/02/26.
//

import SwiftUI

struct StatsLeadersView: View {
    let tournament: Tournament

    @State private var categories: [StatCategory] = []
    @State private var currentPage: Int = 0
    @State private var isLoading = true
    @State private var errorMessage: String?

    // Filter out categories with no stats
    private var activeCategories: [StatCategory] {
        categories.filter { $0.name != nil && !$0.stats.isEmpty }
    }

    var body: some View {
        Group {
            if isLoading {
                AppTheme.LoadingView(message: "Loading stats...")
            } else if let error = errorMessage {
                AppTheme.ErrorView(message: error) {
                    Task { await loadStats() }
                }
            } else if activeCategories.isEmpty {
                AppTheme.EmptyStateView(
                    icon: "chart.bar.xaxis",
                    message: "No hay estadisticas disponibles."
                )
            } else {
                statsContent
            }
        }
        .task {
            await loadStats()
        }
    }

    // MARK: - Stats Content

    // Dynamic height for content
    private var carouselHeight: CGFloat {
        let titleArea: CGFloat = 50
        let podiumHeight: CGFloat = 260
        let rowHeight: CGFloat = 44 + AppTheme.Layout.cardPadding * 2
        let rowSpacing = AppTheme.Spacing.medium
        let maxRows = activeCategories.map { max(0, $0.stats.count - 3) }.max() ?? 0
        let restHeight = CGFloat(maxRows) * (rowHeight + rowSpacing)
        return titleArea + podiumHeight + restHeight + 40
    }

    private var statsContent: some View {
        VStack(spacing: AppTheme.Spacing.standard) {
            // Carousel — fixed to 5 player rows
            TabView(selection: $currentPage) {
                ForEach(Array(activeCategories.enumerated()), id: \.element.id) { index, category in
                    categoryPage(category)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.3), value: currentPage)
            .frame(height: carouselHeight)

            // Page indicator dots
            pageIndicator

            Spacer()
        }
    }

    // MARK: - Page Indicator

    private var pageIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<activeCategories.count, id: \.self) { index in
                Capsule()
                    .fill(index == currentPage ? AppTheme.Colors.accent : Color(white: 0.3))
                    .frame(
                        width: index == currentPage ? 20 : 8,
                        height: 8
                    )
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentPage)
            }
        }
        .padding(.top, AppTheme.Spacing.small)
    }

    // MARK: - Category Page

    private func categoryPage(_ category: StatCategory) -> some View {
        let top3 = Array(category.stats.prefix(3))
        let rest = Array(category.stats.dropFirst(3))

        return ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: AppTheme.Spacing.large) {
                    // Podium top 3
                    if top3.count >= 3 {
                        VStack(spacing: 0) {
                            // Category title inside card
                            Text(category.name ?? "")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(AppTheme.Colors.primaryText)
                                .frame(maxWidth: .infinity)
                                .padding(.top, AppTheme.Layout.cardPadding)
                                .padding(.bottom, AppTheme.Spacing.small)

                            podiumView(top3: top3)
                                .padding(.horizontal, AppTheme.Layout.cardPadding)
                                .padding(.bottom, AppTheme.Layout.cardPadding)
                        }
                        .background(
                            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large)
                                .fill(Color(white: 0.1))
                                .stroke(Color(white: 0.2), lineWidth: 1)
                        )
                    } else {
                        // Less than 3 players — show title + regular rows
                        Text(category.name ?? "")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(AppTheme.Colors.primaryText)
                        ForEach(Array(top3.enumerated()), id: \.element.id) { index, stat in
                            NavigationLink {
                                PlayerDetailView(stat: stat, tournamentId: tournament.id)
                            } label: {
                                playerRow(stat: stat, rank: index + 1)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Rest of players
                    if !rest.isEmpty {
                        LazyVStack(spacing: AppTheme.Spacing.medium) {
                            ForEach(Array(rest.enumerated()), id: \.element.id) { index, stat in
                                NavigationLink {
                                    PlayerDetailView(stat: stat, tournamentId: tournament.id)
                                } label: {
                                    playerRow(stat: stat, rank: index + 4)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, AppTheme.Layout.screenPadding)
                .padding(.bottom, AppTheme.Spacing.huge)
            }
    }

    // MARK: - Podium View

    private func podiumView(top3: [PlayerStatEntry]) -> some View {
        let first = top3[0]
        let second = top3[1]
        let third = top3[2]

        return HStack(alignment: .bottom, spacing: 12) {
            // #2 — Left
            NavigationLink {
                PlayerDetailView(stat: second, tournamentId: tournament.id)
            } label: {
                podiumPlayer(stat: second, rank: 2, imageSize: 70, offsetY: 20)
            }
            .buttonStyle(.plain)

            // #1 — Center (tallest)
            NavigationLink {
                PlayerDetailView(stat: first, tournamentId: tournament.id)
            } label: {
                podiumPlayer(stat: first, rank: 1, imageSize: 90, offsetY: 0)
            }
            .buttonStyle(.plain)

            // #3 — Right
            NavigationLink {
                PlayerDetailView(stat: third, tournamentId: tournament.id)
            } label: {
                podiumPlayer(stat: third, rank: 3, imageSize: 70, offsetY: 20)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 10)
        .padding(.bottom, 10)
    }

    private func podiumPlayer(stat: PlayerStatEntry, rank: Int, imageSize: CGFloat, offsetY: CGFloat) -> some View {
        VStack(spacing: 6) {
            // Crown for #1
            if rank == 1 {
                CrownIcon()
                    .fill(AppTheme.Colors.accent)
                    .frame(width: 28, height: 20)
            }

            // Player image with rank badge
            ZStack(alignment: .bottom) {
                podiumAvatar(stat.player, size: imageSize, rank: rank)

                // Rank badge
                Text("\(rank)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.Colors.accentText)
                    .frame(width: 24, height: 24)
                    .background(
                        Circle()
                            .fill(AppTheme.Colors.accent)
                    )
                    .offset(y: 12)
            }

            // Name
            Text(stat.player.firstName)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(AppTheme.Colors.primaryText)
                .lineLimit(1)
                .padding(.top, 8)

            Text(stat.teamName)
                .font(.system(size: 11))
                .foregroundStyle(Color(white: 0.5))
                .lineLimit(1)

            // Score
            Text("\(stat.score)")
                .font(.system(size: 26, weight: .heavy))
                .foregroundStyle(AppTheme.Colors.accent)
                .shadow(color: AppTheme.Colors.accent.opacity(0.6), radius: 8, x: 0, y: 0)
                .shadow(color: AppTheme.Colors.accent.opacity(0.3), radius: 16, x: 0, y: 0)
        }
        .frame(maxWidth: .infinity)
        .offset(y: offsetY)
    }

    private func podiumAvatar(_ player: Player, size: CGFloat, rank: Int) -> some View {
        let borderColor = rank == 1 ? AppTheme.Colors.accent : Color(white: 0.3)
        let borderWidth: CGFloat = rank == 1 ? 3 : 2

        return Group {
            if let picture = player.picture,
               let url = URL(string: picture.hasPrefix("http") ? picture : "\(APIConfig.baseURL)/\(picture)") {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: size, height: size)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(borderColor, lineWidth: borderWidth))
                    default:
                        podiumInitials(player, size: size, borderColor: borderColor, borderWidth: borderWidth)
                    }
                }
            } else {
                podiumInitials(player, size: size, borderColor: borderColor, borderWidth: borderWidth)
            }
        }
    }

    private func podiumInitials(_ player: Player, size: CGFloat, borderColor: Color, borderWidth: CGFloat) -> some View {
        Circle()
            .fill(Color(white: 0.15))
            .frame(width: size, height: size)
            .overlay(
                Text(playerInitials(player))
                    .font(.system(size: size * 0.3, weight: .bold))
                    .foregroundStyle(Color(white: 0.4))
            )
            .overlay(Circle().stroke(borderColor, lineWidth: borderWidth))
    }

    // MARK: - Player Row

    private func playerRow(stat: PlayerStatEntry, rank: Int) -> some View {
        HStack(spacing: AppTheme.Spacing.medium) {
            // Rank
            rankIndicator(rank: rank)

            // Player avatar
            playerAvatar(stat.player)

            // Name and team
            VStack(alignment: .leading, spacing: 2) {
                Text(stat.player.fullName)
                    .font(AppTheme.Typography.bodyBold)
                    .foregroundStyle(AppTheme.Colors.primaryText)
                    .lineLimit(1)

                Text(stat.teamName)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .lineLimit(1)
            }

            Spacer()

            // Score
            Text("\(stat.score)")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AppTheme.Colors.accent)
        }
        .cardStyle()
    }

    // MARK: - Rank Indicator

    private func rankIndicator(rank: Int) -> some View {
        Group {
            if rank <= 3 {
                AppTheme.PositionCircle(position: rank, size: 32)
            } else {
                ZStack {
                    Circle()
                        .fill(Color(white: 0.2))
                        .frame(width: 32, height: 32)

                    Text("\(rank)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }
            }
        }
    }

    // MARK: - Player Avatar

    private func playerAvatar(_ player: Player) -> some View {
        Group {
            if let picture = player.picture,
               let url = URL(string: picture.hasPrefix("http") ? picture : "\(APIConfig.baseURL)/\(picture)") {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        avatarPlaceholder(player)
                    default:
                        avatarPlaceholder(player)
                    }
                }
            } else {
                avatarPlaceholder(player)
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small))
    }

    private func avatarPlaceholder(_ player: Player) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small)
                .fill(Color(white: 0.25))

            Text(playerInitials(player))
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(AppTheme.Colors.secondaryText)
        }
    }

    private func playerInitials(_ player: Player) -> String {
        let first = player.firstName.prefix(1)
        let last = player.lastName.prefix(1)
        return "\(first)\(last)".uppercased()
    }

    // MARK: - Data Loading

    private func loadStats() async {
        isLoading = true
        errorMessage = nil

        do {
            categories = try await APIService.shared.fetchTopStats(for: tournament.id)
            isLoading = false
        } catch {
            errorMessage = "Failed to load stats"
            isLoading = false
            print("❌ Stats loading error: \(error)")
        }
    }
}
 
// MARK: - Custom Crown Shape

struct CrownIcon: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height

        var path = Path()

        // Angular crown: 5 points up, 2 valleys
        // Left base
        path.move(to: CGPoint(x: 0, y: h))
        // Left peak
        path.addLine(to: CGPoint(x: 0, y: h * 0.35))
        // Left valley
        path.addLine(to: CGPoint(x: w * 0.25, y: h * 0.55))
        // Center peak (tallest)
        path.addLine(to: CGPoint(x: w * 0.5, y: 0))
        // Right valley
        path.addLine(to: CGPoint(x: w * 0.75, y: h * 0.55))
        // Right peak
        path.addLine(to: CGPoint(x: w, y: h * 0.35))
        // Right base
        path.addLine(to: CGPoint(x: w, y: h))
        path.closeSubpath()

        return path
    }
}
