//
//  TournamentContainerView.swift
//  Brackets
//
//  Created by Humberto on 16/02/26.
//

import SwiftUI

enum TournamentTab: String, CaseIterable {
    case standings = "Standings"
    case games = "Games"
    case stats = "Stats Leaders"
    
    var icon: String {
        switch self {
        case .standings: return "chart.bar.fill"
        case .games: return "sportscourt.fill"
        case .stats: return "star.fill"
        }
    }
    
    var displayName: String {
        switch self {
        case .standings: return "Standings"
        case .games: return "Games"
        case .stats: return "Stats"
        }
    }
}

struct TournamentContainerView: View {
    let tournament: Tournament
    @State private var selectedTab: TournamentTab = .standings
    @Environment(\.dismiss) private var dismiss
    @Namespace private var animation
    
    var body: some View {
        ZStack {
            // Background
            AppTheme.Colors.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header with back button and title
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
                    
                    Text(tournament.name)
                        .font(AppTheme.Typography.largeTitle)
                        .foregroundStyle(AppTheme.Colors.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    
                    Spacer()
                }
                .padding(.horizontal, AppTheme.Layout.extraLarge)
                .padding(.top, AppTheme.Layout.large)
                .padding(.bottom, AppTheme.Layout.itemSpacing)
                
                // Content based on selected tab
                ZStack {
                    if selectedTab == .standings {
                        StandingsView(tournament: tournament)
                    } else if selectedTab == .games {
                        GamesListView(tournament: tournament)
                    } else if selectedTab == .stats {
                        StatsLeadersView(tournament: tournament)
                    }
                }
                
                // Bottom Tab Bar - Matching the design from image
                CustomTabBar(selectedTab: $selectedTab, namespace: animation)
                    .padding(.horizontal, 40)
                    .padding(.bottom, AppTheme.Layout.large)
                    .padding(.top, AppTheme.Spacing.medium)
            }
        }
        .navigationBarHidden(true)
    }
}

struct CustomTabBar: View {
    @Binding var selectedTab: TournamentTab
    let namespace: Namespace.ID
    
    var body: some View {
        HStack(spacing: 12) {
            // First Tab (Home/Standings) - Circle
            TabButton(
                tab: .standings,
                isSelected: selectedTab == .standings,
                namespace: namespace
            ) {
                selectedTab = .standings
            }
            
            // Second Tab (Games/Progress) - Elongated Pill (always selected in design)
            TabButton(
                tab: .games,
                isSelected: selectedTab == .games,
                namespace: namespace
            ) {
                selectedTab = .games
            }
            
            // Third Tab (Stats) - Circle
            TabButton(
                tab: .stats,
                isSelected: selectedTab == .stats,
                namespace: namespace
            ) {
                selectedTab = .stats
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 40)
                .fill(Color(white: 0.15))
        )
    }
}

struct TabButton: View {
    let tab: TournamentTab
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                action()
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: tab.icon)
                    .font(.system(size: 20, weight: .semibold))
                
                // Show label only when selected
                if isSelected {
                    Text(tab.displayName)
                        .font(.system(size: 17, weight: .bold))
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .foregroundStyle(isSelected ? AppTheme.Colors.accentText : AppTheme.Colors.primaryText)
            .frame(width: isSelected ? nil : 52, height: 52)
            .padding(.horizontal, isSelected ? 20 : 0)
            .background {
                if isSelected {
                    Capsule()
                        .fill(AppTheme.Colors.accent)
                        .matchedGeometryEffect(id: "tab_background", in: namespace)
                } else {
                    Circle()
                        .fill(Color(white: 0.2))
                }
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    TournamentContainerView(
        tournament: Tournament(
            id: 1,
            name: "Juvenil Varonil",
            gender: .male,
            teamCount: 8,
            image: nil
        )
    )
}

