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
        categories.filter { !$0.stats.isEmpty }
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
                    message: "No stats available"
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

    private var statsContent: some View {
        VStack(spacing: AppTheme.Spacing.standard) {
            // Page indicator dots
            pageIndicator

            // Carousel
            TabView(selection: $currentPage) {
                ForEach(Array(activeCategories.enumerated()), id: \.element.id) { index, category in
                    categoryPage(category)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.3), value: currentPage)
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
        VStack(spacing: AppTheme.Spacing.standard) {
            // Category title
            HStack(spacing: 8) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AppTheme.Colors.accent)

                Text(category.name)
                    .font(AppTheme.Typography.title)
                    .foregroundStyle(AppTheme.Colors.primaryText)
            }
            .padding(.bottom, AppTheme.Spacing.extraSmall)

            // Player list
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: AppTheme.Spacing.medium) {
                    ForEach(Array(category.stats.enumerated()), id: \.element.id) { index, stat in
                        playerRow(stat: stat, rank: index + 1)
                    }
                }
                .padding(.horizontal, AppTheme.Layout.screenPadding)
                .padding(.bottom, AppTheme.Spacing.huge)
            }
        }
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
