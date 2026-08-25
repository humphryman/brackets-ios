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

    private func formatScore(_ score: Double) -> String {
        tournament.usesAverage ? String(format: "%.1f", score) : String(format: "%.0f", score)
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

    private var statsContent: some View {
        VStack(spacing: 0) {
            // Carousel fills the available content area; each page scrolls internally,
            // so the tournament header and floating tab bar stay visible.
            TabView(selection: $currentPage) {
                ForEach(Array(activeCategories.enumerated()), id: \.element.id) { index, category in
                    categoryPage(category)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.3), value: currentPage)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Page indicator dots — centered in the space between the card and the tab bar
            pageIndicator
        }
        .padding(.bottom, 60) // clear the floating bottom tab bar so the dots stay visible
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
        .padding(.vertical, AppTheme.Spacing.medium)
    }

    // MARK: - Category Page

    private func categoryPage(_ category: StatCategory) -> some View {
        let top3 = Array(category.stats.prefix(3))
        let rest = Array(category.stats.dropFirst(3))
        let statKey = category.stats.first?.statName ?? ""

        return GeometryReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    // Title
                    Text(category.name ?? "")
                        .font(AppTheme.Typography.condensed(.semibold, size: 24))
                        .foregroundStyle(AppTheme.Colors.primaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppTheme.Spacing.medium)

                    Divider().overlay(AppTheme.Colors.gray700)

                    // Podium (top 3) or fallback rows
                    if top3.count >= 3 {
                        podiumView(top3: top3)
                            .padding(.horizontal, AppTheme.Layout.cardPadding)
                            .padding(.top, AppTheme.Spacing.large)
                            .padding(.bottom, AppTheme.Spacing.extraLarge)
                    } else {
                        ForEach(Array(top3.enumerated()), id: \.element.id) { index, stat in
                            statRowLink(stat: stat, rank: index + 1)
                            if index < top3.count - 1 {
                                Divider().overlay(AppTheme.Colors.gray700).padding(.horizontal, AppTheme.Layout.cardPadding)
                            }
                        }
                    }

                    // Rest of the players — hairline between each row
                    if !rest.isEmpty {
                        Divider().overlay(AppTheme.Colors.gray700)
                    }
                    ForEach(Array(rest.enumerated()), id: \.element.id) { index, stat in
                        statRowLink(stat: stat, rank: index + 4)

                        if index < rest.count - 1 {
                            Divider()
                                .overlay(AppTheme.Colors.gray700)
                                .padding(.horizontal, AppTheme.Layout.cardPadding)
                        }
                    }

                    // Keep the footer at the bottom of the card when content is short
                    Spacer(minLength: AppTheme.Spacing.medium)

                    // Footer link → full list
                    if !category.stats.isEmpty {
                        Divider().overlay(AppTheme.Colors.gray700).padding(.horizontal, AppTheme.Layout.cardPadding)
                        NavigationLink {
                            TopStatDetailView(tournament: tournament, stat: statKey, categoryName: category.name ?? "")
                        } label: {
                            Text("Ver listado completo")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(AppTheme.Colors.accent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, AppTheme.Spacing.medium)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(minHeight: proxy.size.height, alignment: .top)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large)
                        .fill(AppTheme.Colors.gray800)
                        .strokeBorder(AppTheme.Colors.gray700, lineWidth: 1)
                )
                .padding(.horizontal, 6)
            }
        }
    }

    private func statRowLink(stat: PlayerStatEntry, rank: Int) -> some View {
        NavigationLink {
            PlayerDetailView(stat: stat, tournamentId: tournament.id)
        } label: {
            statListRow(stat: stat, rank: rank)
        }
        .buttonStyle(.plain)
    }

    private func statListRow(stat: PlayerStatEntry, rank: Int) -> some View {
        HStack(spacing: AppTheme.Spacing.medium) {
            Text("\(rank)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .frame(width: 24, alignment: .center)

            circularAvatar(stat.player, size: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(stat.player.fullName)
                    .font(AppTheme.Typography.bodyBold)
                    .foregroundStyle(AppTheme.Colors.primaryText)
                    .lineLimit(1)
                Text(stat.teamName)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.gray400)
                    .lineLimit(1)
            }

            Spacer()

            Text(formatScore(stat.score))
                .font(AppTheme.Typography.condensed(.semibold, size: 26))
                .foregroundStyle(AppTheme.Colors.primaryText)
        }
        .padding(.horizontal, AppTheme.Layout.cardPadding)
        .padding(.vertical, AppTheme.Spacing.medium)
        .frame(maxWidth: .infinity)
        .background(AppTheme.Colors.gray800)
    }

    private func circularAvatar(_ player: Player, size: CGFloat) -> some View {
        Group {
            if let picture = player.picture,
               let url = URL(string: picture.hasPrefix("http") ? picture : "\(APIConfig.baseURL)/\(picture)") {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        avatarPlaceholder(player)
                    }
                }
            } else {
                avatarPlaceholder(player)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
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
                podiumPlayer(stat: second, rank: 2, imageSize: 84, offsetY: 22)
            }
            .buttonStyle(.plain)

            // #1 — Center (tallest)
            NavigationLink {
                PlayerDetailView(stat: first, tournamentId: tournament.id)
            } label: {
                podiumPlayer(stat: first, rank: 1, imageSize: 108, offsetY: 0)
            }
            .buttonStyle(.plain)

            // #3 — Right
            NavigationLink {
                PlayerDetailView(stat: third, tournamentId: tournament.id)
            } label: {
                podiumPlayer(stat: third, rank: 3, imageSize: 72, offsetY: 30)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 10)
        .padding(.bottom, 10)
    }

    private func podiumPlayer(stat: PlayerStatEntry, rank: Int, imageSize: CGFloat, offsetY: CGFloat) -> some View {
        let metal = PodiumMetal(rank: rank)

        return VStack(spacing: 1) {
            // Player image with rank badge
            ZStack(alignment: .bottom) {
                podiumAvatar(stat.player, size: imageSize, rank: rank)

                // Rank badge — dark disc ringed in the place's metal
                Text("\(rank)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(metal.color)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(AppTheme.Colors.gray800))
                    .overlay(Circle().strokeBorder(metal.color, lineWidth: 1.5))
                    .offset(y: 12)
            }

            // Name
            Text(stat.player.firstName)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(AppTheme.Colors.primaryText)
                .lineLimit(1)
                // clears the rank badge, which overhangs the avatar by 12
                .padding(.top, 16)

            Text(stat.teamName)
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.Colors.gray400)
                .lineLimit(1)

            // Score
            Text(formatScore(stat.score))
                .font(AppTheme.Typography.condensed(.semibold, size: 34))
                .foregroundStyle(AppTheme.Colors.primaryText)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .offset(y: offsetY)
    }

    private func podiumAvatar(_ player: Player, size: CGFloat, rank: Int) -> some View {
        let metal = PodiumMetal(rank: rank)

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
                    default:
                        podiumInitials(player, size: size)
                    }
                }
            } else {
                podiumInitials(player, size: size)
            }
        }
        .background {
            if metal.isGold {
                GoldGlow()
                    // Kept close to the photo so it never reaches the neighbouring
                    // places, and lifted slightly so it reads as light from above.
                    .frame(width: size * 1.34, height: size * 1.34)
                    .offset(y: -10)
                    .allowsHitTesting(false)
            }
        }
        .overlay { metal.ring(width: metal.isGold ? 3 : 2) }
    }

    private func podiumInitials(_ player: Player, size: CGFloat) -> some View {
        Circle()
            .fill(Color(white: 0.15))
            .frame(width: size, height: size)
            .overlay(
                Text(playerInitials(player))
                    .font(.system(size: size * 0.3, weight: .bold))
                    .foregroundStyle(Color(white: 0.4))
            )
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

// MARK: - Podium Metals

/// Gold, silver and bronze for the three podium places. Only gold moves: a highlight
/// sweeps across its ring so first place reads as the shiny one.
private struct PodiumMetal {
    let rank: Int

    var isGold: Bool { rank == 1 }

    var color: Color {
        switch rank {
        case 1:  AppTheme.Colors.gold
        case 2:  AppTheme.Colors.silver
        default: AppTheme.Colors.bronze
        }
    }

    func ring(width: CGFloat) -> some View {
        Circle().strokeBorder(color, lineWidth: width)
    }
}

/// A soft gold halo that breathes behind the first-place photo: two offset radial
/// gradients drifting against each other, so the light shifts instead of just pulsing.
private struct GoldGlow: View {
    @State private var isBreathing = false

    var body: some View {
        ZStack {
            halo(opacity: 0.55, blur: 18)
                .scaleEffect(isBreathing ? 1.06 : 0.92)

            halo(opacity: 0.30, blur: 30)
                .scaleEffect(isBreathing ? 0.94 : 1.10)
        }
        .opacity(isBreathing ? 1.0 : 0.72)
        .onAppear {
            withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
                isBreathing = true
            }
        }
    }

    private func halo(opacity: Double, blur: CGFloat) -> some View {
        GeometryReader { proxy in
            RadialGradient(
                stops: [
                    .init(color: AppTheme.Colors.goldHighlight.opacity(opacity), location: 0.0),
                    .init(color: AppTheme.Colors.gold.opacity(opacity * 0.8), location: 0.45),
                    .init(color: AppTheme.Colors.gold.opacity(0), location: 1.0)
                ],
                center: .center,
                startRadius: 0,
                endRadius: proxy.size.width / 2
            )
            .blur(radius: blur)
        }
    }
}
