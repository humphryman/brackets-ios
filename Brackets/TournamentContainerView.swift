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
    case bracket = "Bracket"

    var icon: String {
        switch self {
        case .standings: return "list.number"
        case .games: return "basketball.fill"
        case .stats: return "chart.bar.fill"
        case .bracket: return "trophy"
        }
    }

    var displayName: String {
        switch self {
        case .standings: return "Standings"
        case .games: return "Games"
        case .stats: return "Stats"
        case .bracket: return "Bracket"
        }
    }
}

struct TournamentContainerView: View {
    let tournament: Tournament
    @State private var selectedTab: TournamentTab = .standings
    @Environment(\.dismiss) private var dismiss
    @Namespace private var animation

    private var availableTabs: [TournamentTab] {
        var tabs: [TournamentTab] = [.standings]
        if tournament.isPlayoffs {
            tabs.append(.bracket)
        }
        tabs.append(contentsOf: [.games, .stats])
        return tabs
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Background
            AppTheme.Colors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header with back button and tournament name
                ZStack {
                    Text(tournament.name)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(AppTheme.Colors.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)

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
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 16)

                // Content based on selected tab
                ZStack {
                    switch selectedTab {
                    case .standings:
                        StandingsView(tournament: tournament)
                    case .games:
                        GamesListView(tournament: tournament)
                    case .stats:
                        StatsLeadersView(tournament: tournament)
                    case .bracket:
                        BracketView(tournament: tournament)
                    }
                }
            }

            // Floating bottom tab bar
            VStack {
                Spacer()
                CustomTabBar(selectedTab: $selectedTab, tabs: availableTabs, namespace: animation)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 10)
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .navigationBarHidden(true)
    }
}

struct CustomTabBar: View {
    @Binding var selectedTab: TournamentTab
    var tabs: [TournamentTab] = [.standings, .games, .stats]
    let namespace: Namespace.ID

    var body: some View {
        HStack(spacing: 12) {
            ForEach(tabs, id: \.self) { tab in
                TabButton(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    namespace: namespace
                ) {
                    selectedTab = tab
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 40)
                .fill(Color(white: 0.15).opacity(0.6))
        )
        .background(
            RoundedRectangle(cornerRadius: 40)
                .fill(.ultraThinMaterial)
        )
        .fixedSize(horizontal: true, vertical: false)
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
                if tab == .bracket {
                    BracketIcon()
                        .frame(width: 20, height: 20)
                } else {
                    Image(systemName: tab.icon)
                        .font(.system(size: 20, weight: .semibold))
                }

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

// MARK: - Custom Bracket Icon

struct BracketIcon: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let lineWidth: CGFloat = 2

            var path = Path()

            // Top branch
            // Top-left horizontal
            path.move(to: CGPoint(x: 0, y: h * 0.1))
            path.addLine(to: CGPoint(x: w * 0.35, y: h * 0.1))
            // Vertical down to mid-top
            path.addLine(to: CGPoint(x: w * 0.35, y: h * 0.35))
            // Bottom-left horizontal (of top pair)
            path.move(to: CGPoint(x: 0, y: h * 0.35))
            path.addLine(to: CGPoint(x: w * 0.35, y: h * 0.35))
            // Connector from mid of top pair to right
            path.move(to: CGPoint(x: w * 0.35, y: h * 0.225))
            path.addLine(to: CGPoint(x: w * 0.65, y: h * 0.225))

            // Bottom branch
            // Top-left horizontal (of bottom pair)
            path.move(to: CGPoint(x: 0, y: h * 0.65))
            path.addLine(to: CGPoint(x: w * 0.35, y: h * 0.65))
            // Vertical down
            path.addLine(to: CGPoint(x: w * 0.35, y: h * 0.9))
            // Bottom-left horizontal
            path.move(to: CGPoint(x: 0, y: h * 0.9))
            path.addLine(to: CGPoint(x: w * 0.35, y: h * 0.9))
            // Connector from mid of bottom pair to right
            path.move(to: CGPoint(x: w * 0.35, y: h * 0.775))
            path.addLine(to: CGPoint(x: w * 0.65, y: h * 0.775))

            // Final vertical connector
            path.move(to: CGPoint(x: w * 0.65, y: h * 0.225))
            path.addLine(to: CGPoint(x: w * 0.65, y: h * 0.775))
            // Final horizontal to right
            path.move(to: CGPoint(x: w * 0.65, y: h * 0.5))
            path.addLine(to: CGPoint(x: w, y: h * 0.5))

            context.stroke(path, with: .foreground, lineWidth: lineWidth)
        }
    }
}
