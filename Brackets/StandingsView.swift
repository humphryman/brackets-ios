//
//  StandingsView.swift
//  Brackets
//
//  Created by Humberto on 16/02/26.
//

import SwiftUI

struct StandingsView: View {
    let tournament: Tournament
    @State private var standings: [TeamStanding] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        ZStack {
            if isLoading {
                AppTheme.LoadingView(message: "Loading standings...")
            } else if let errorMessage = errorMessage {
                AppTheme.ErrorView(message: errorMessage) {
                    Task {
                        await loadStandings()
                    }
                }
            } else if standings.isEmpty {
                AppTheme.EmptyStateView(
                    icon: "chart.bar",
                    message: "No standings available"
                )
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header with trophy icon
                        HStack(spacing: AppTheme.Spacing.medium) {
                            Image(systemName: "trophy.fill")
                                .font(AppTheme.Typography.title)
                                .foregroundStyle(AppTheme.Colors.accent)
                            
                            Text("Standings")
                                .font(AppTheme.Typography.largeTitle)
                                .foregroundStyle(AppTheme.Colors.primaryText)
                        }
                        .padding(.horizontal, AppTheme.Layout.screenPadding)
                        .padding(.top, AppTheme.Layout.large)
                        
                        // Standings Cards
                        VStack(spacing: AppTheme.Layout.itemSpacing) {
                            ForEach(Array(standings.enumerated()), id: \.element.id) { index, standing in
                                StandingCard(position: index + 1, standing: standing)
                            }
                        }
                        .padding(.horizontal, AppTheme.Layout.screenPadding)
                        .padding(.bottom, AppTheme.Layout.large)
                    }
                }
            }
        }
        .task {
            await loadStandings()
        }
    }
    
    private func loadStandings() async {
        isLoading = true
        errorMessage = nil
        
        do {
            standings = try await APIService.shared.fetchStandings(for: tournament.id)
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}

struct StandingCard: View {
    let position: Int
    let standing: TeamStanding
    
    var body: some View {
        HStack(spacing: 0) {
            // Position Circle
            AppTheme.PositionCircle(position: position)
                .padding(.trailing, AppTheme.Spacing.medium)
            
            // Team Name
            Text(standing.teamName)
                .font(AppTheme.Typography.bodyBold)
                .foregroundStyle(AppTheme.Colors.primaryText)
                .textCase(.uppercase)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            
            Spacer(minLength: AppTheme.Spacing.small)
            
            // Stats: FAV, CON, DIFF
            HStack(spacing: AppTheme.Spacing.medium) {
                StatColumn(value: standing.pointsFor, label: "FAV")
                StatColumn(value: standing.pointsAgainst, label: "CON")
                DiffColumn(value: standing.pointDifferential)
            }
            .padding(.trailing, AppTheme.Spacing.medium)
            
            // Record Badge
            AppTheme.RecordBadge(record: standing.record)
        }
        .cardStyle()
    }
}

struct StatColumn: View {
    let value: Int
    let label: String
    
    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(AppTheme.Typography.bodyBold)
                .foregroundStyle(AppTheme.Colors.primaryText)
            
            Text(label)
                .font(AppTheme.Typography.tinyCaption)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .textCase(.uppercase)
        }
        .frame(minWidth: 36)
    }
}

struct DiffColumn: View {
    let value: Int
    
    var isPositive: Bool {
        value > 0
    }
    
    var isNegative: Bool {
        value < 0
    }
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value > 0 ? "+\(value)" : "\(value)")
                .font(AppTheme.Typography.bodyBold)
                .foregroundStyle(isPositive ? AppTheme.Colors.positive : (isNegative ? AppTheme.Colors.negative : AppTheme.Colors.neutral))
            
            Text("DIFF")
                .font(AppTheme.Typography.tinyCaption)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .textCase(.uppercase)
        }
        .frame(minWidth: 36)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        StandingsView(
            tournament: Tournament(
                id: 1,
                name: "Juvenil Varonil",
                gender: .male,
                teamCount: 8,
                image: nil
            )
        )
    }
}

