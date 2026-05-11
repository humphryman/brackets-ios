//
//  StandingsView.swift
//  Brackets
//
//  Created by Humberto on 16/02/26.
//

import SwiftUI

struct StandingsView: View {
    let tournament: Tournament
    @State private var result: StandingsResult?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var presentedTiebreaker: Tiebreaker?

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
            } else if result == nil || result!.isEmpty {
                AppTheme.EmptyStateView(
                    icon: "chart.bar",
                    message: "No standings available"
                )
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        switch result! {
                        case .flat(let standings):
                            standingsList(standings)
                        case .groups(let groups):
                            ForEach(groups) { group in
                                VStack(alignment: .leading, spacing: AppTheme.Layout.itemSpacing) {
                                    Text(group.name.capitalized)
                                        .font(AppTheme.Typography.bodyBold)
                                        .foregroundStyle(AppTheme.Colors.primaryText)
                                        .padding(.horizontal, AppTheme.Layout.screenPadding)
                                        .padding(.top, AppTheme.Spacing.medium)

                                    standingsList(group.standings)
                                }
                            }
                        }
                    }
                    .padding(.bottom, AppTheme.Layout.large)
                }
            }
        }
        .sheet(item: $presentedTiebreaker) { tb in
            TiebreakerSheet(tiebreaker: tb)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .task {
            await loadStandings()
        }
    }

    @ViewBuilder
    private func standingsList(_ standings: [TeamStanding]) -> some View {
        VStack(spacing: AppTheme.Layout.itemSpacing) {
            ForEach(Array(standings.enumerated()), id: \.element.id) { index, standing in
                ZStack {
                    NavigationLink {
                        TeamDetailView(standing: standing, tournamentId: tournament.id, tournamentName: tournament.name, rank: index + 1)
                    } label: {
                        EmptyView()
                    }
                    .opacity(0)

                    StandingCard(
                        position: index + 1,
                        standing: standing,
                        usesAverage: tournament.usesAverage,
                        onTiebreakerTap: standing.tiebreaker.map { tb in { presentedTiebreaker = tb } }
                    )
                }
            }
        }
        .padding(.horizontal, AppTheme.Layout.screenPadding)
    }

    private func loadStandings() async {
        isLoading = true
        errorMessage = nil

        do {
            result = try await APIService.shared.fetchStandings(for: tournament.id)
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
    let usesAverage: Bool
    var onTiebreakerTap: (() -> Void)? = nil

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
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            Spacer(minLength: AppTheme.Spacing.small)

            // Tiebreaker info icon (only when tiebreaker present)
            if standing.tiebreaker != nil, let onTap = onTiebreakerTap {
                Button(action: onTap) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.trailing, 6)
            }

            // Stats: FAV, CON, DIFF or AVG
            HStack(spacing: 8) {
                StatColumn(value: standing.pointsFor, label: "FAV")
                StatColumn(value: standing.pointsAgainst, label: "CON")
                if usesAverage {
                    AvgColumn(value: standing.avg)
                } else {
                    DiffColumn(value: standing.pointDifferential)
                }
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

            Text("DIF")
                .font(AppTheme.Typography.tinyCaption)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .textCase(.uppercase)
        }
        .frame(minWidth: 36)
    }
}

struct AvgColumn: View {
    let value: Double?

    private var color: Color {
        guard let value else { return AppTheme.Colors.neutral }
        if value > 0 { return AppTheme.Colors.positive }
        if value < 0 { return AppTheme.Colors.negative }
        return AppTheme.Colors.neutral
    }

    private var formatted: String {
        guard let value else { return "-" }
        let base = String(format: "%.1f", value)
        return value > 0 ? "+\(base)" : base
    }

    var body: some View {
        VStack(spacing: 2) {
            Text(formatted)
                .font(AppTheme.Typography.bodyBold)
                .foregroundStyle(color)

            Text("AVG")
                .font(AppTheme.Typography.tinyCaption)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .textCase(.uppercase)
        }
        .frame(minWidth: 48)
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

