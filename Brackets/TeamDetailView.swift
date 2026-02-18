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
        switch selectedTab {
        case .games:
            TeamGamesTabView()
        case .players:
            TeamPlayersTabView()
        case .stats:
            TeamStatsTabView()
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

// MARK: - Tab Views

struct TeamGamesTabView: View {
    var body: some View {
        VStack(spacing: AppTheme.Spacing.large) {
            Spacer()
            Image(systemName: "sportscourt")
                .font(.system(size: 40))
                .foregroundStyle(Color(white: 0.3))
            Text("Team Games")
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

struct TeamPlayersTabView: View {
    var body: some View {
        VStack(spacing: AppTheme.Spacing.large) {
            Spacer()
            Image(systemName: "person.3")
                .font(.system(size: 40))
                .foregroundStyle(Color(white: 0.3))
            Text("Players")
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
