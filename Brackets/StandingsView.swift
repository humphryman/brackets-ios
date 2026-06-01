//
//  StandingsView.swift
//  Brackets
//
//  Created by Humberto on 16/02/26.
//

import SwiftUI

enum StandingsSubTab {
    case champion
    case standings
}

struct StandingsView: View {
    let tournament: Tournament
    @State private var bundle: StandingsBundle?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var presentedTiebreaker: Tiebreaker?
    @State private var selectedSubTab: StandingsSubTab

    init(tournament: Tournament) {
        self.tournament = tournament
        _selectedSubTab = State(initialValue: tournament.winner != nil ? .champion : .standings)
    }

    private var hasChampionTab: Bool {
        tournament.winner != nil && bundle?.podium != nil
    }

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
            } else if let bundle = bundle, !bundle.result.isEmpty {
                VStack(spacing: 0) {
                    if hasChampionTab {
                        StandingsSubTabBar(selected: $selectedSubTab)
                            .padding(.horizontal, AppTheme.Layout.screenPadding)
                            .padding(.bottom, AppTheme.Spacing.medium)
                    }

                    if hasChampionTab && selectedSubTab == .champion, let podium = bundle.podium {
                        ChampionPanel(podium: podium)
                    } else {
                        standingsScroll(bundle.result)
                    }
                }
            } else {
                AppTheme.EmptyStateView(
                    icon: "chart.bar",
                    message: "No standings available"
                )
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
    private func standingsScroll(_ result: StandingsResult) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                switch result {
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

    @ViewBuilder
    private func standingsList(_ standings: [TeamStanding]) -> some View {
        VStack(spacing: AppTheme.Layout.itemSpacing) {
            ForEach(Array(standings.enumerated()), id: \.element.id) { index, standing in
                NavigationLink {
                    TeamDetailView(standing: standing, tournamentId: tournament.id, tournamentName: tournament.name, rank: index + 1)
                } label: {
                    StandingCard(
                        position: index + 1,
                        standing: standing,
                        usesAverage: tournament.usesAverage,
                        onTiebreakerTap: standing.tiebreaker.map { tb in { presentedTiebreaker = tb } }
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, AppTheme.Layout.screenPadding)
    }

    private func loadStandings() async {
        isLoading = true
        errorMessage = nil

        do {
            bundle = try await APIService.shared.fetchStandings(for: tournament.id)
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

// MARK: - Sub-tab bar

struct StandingsSubTabBar: View {
    @Binding var selected: StandingsSubTab

    var body: some View {
        HStack(spacing: AppTheme.Spacing.small) {
            subTabButton(title: "Campeón", value: .champion)
            subTabButton(title: "Standings", value: .standings)
            Spacer()
        }
    }

    @ViewBuilder
    private func subTabButton(title: String, value: StandingsSubTab) -> some View {
        let isSelected = selected == value
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selected = value
            }
        } label: {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isSelected ? AppTheme.Colors.accentText : AppTheme.Colors.primaryText)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? AppTheme.Colors.accent : Color(white: 0.15))
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Champion Panel

struct ChampionPanel: View {
    let podium: Podium

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                // Title block
                VStack(spacing: 4) {
                    Text(podium.first.teamName.uppercased())
                        .font(.system(size: 42, weight: .heavy))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.5)
                        .multilineTextAlignment(.center)
                    Text("CAMPEÓN")
                        .font(.system(size: 42, weight: .heavy))
                        .foregroundStyle(.white)

                    Text(podium.tournamentName.uppercased())
                        .font(.system(size: 13, weight: .semibold))
                        .tracking(2)
                        .foregroundStyle(Color(white: 0.5))
                        .padding(.top, 14)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, AppTheme.Layout.screenPadding)
                .padding(.top, 8)

                // Podium row
                HStack(alignment: .bottom, spacing: 8) {
                    if let second = podium.second {
                        PodiumCard(entry: second, style: .silver, height: 280)
                    } else {
                        Spacer().frame(maxWidth: .infinity)
                    }

                    PodiumCard(entry: podium.first, style: .gold, height: 340)

                    if let third = podium.third {
                        PodiumCard(entry: third, style: .bronze, height: 240)
                    } else {
                        Spacer().frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, AppTheme.Layout.screenPadding)
                .padding(.bottom, AppTheme.Layout.large)
            }
        }
    }
}

private struct PodiumCard: View {
    enum Style {
        case gold, silver, bronze

        var primary: Color {
            switch self {
            case .gold: return AppTheme.Colors.accent
            case .silver: return Color(white: 0.55)
            case .bronze: return Color(red: 0.78, green: 0.42, blue: 0.18)
            }
        }

        var pillTextColor: Color {
            switch self {
            case .gold: return AppTheme.Colors.accentText
            default: return .white
            }
        }

        var cardFill: Color {
            switch self {
            case .gold: return Color(white: 0.10)
            case .silver: return Color(white: 0.12)
            case .bronze: return Color(red: 0.16, green: 0.08, blue: 0.04)
            }
        }
    }

    let entry: PodiumEntry
    let style: Style
    let height: CGFloat

    var body: some View {
        VStack(spacing: 14) {
            // Numbered badge
            ZStack {
                Circle()
                    .fill(style.primary)
                    .frame(width: 36, height: 36)
                Text("\(entry.place)")
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundStyle(style.pillTextColor)
            }
            .offset(y: -18)
            .padding(.bottom, -18)

            if style == .gold {
                Image(systemName: "star.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color(red: 0.98, green: 0.74, blue: 0.18))
            }

            // Logo in colored ring
            ZStack {
                Circle()
                    .fill(Color(white: 0.18))
                logoView
                    .clipShape(Circle())
            }
            .frame(width: 72, height: 72)
            .overlay(
                Circle().stroke(style.primary, lineWidth: 3)
            )

            Text(entry.teamName)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 4)

            Spacer(minLength: 0)

            // Place pill
            Text("\(entry.place)° LUGAR")
                .font(.system(size: 11, weight: .heavy))
                .tracking(1)
                .foregroundStyle(style.pillTextColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(style.primary))
                .padding(.bottom, 14)
        }
        .padding(.top, 24)
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(style.cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(style.primary, lineWidth: 2)
        )
    }

    @ViewBuilder
    private var logoView: some View {
        if let urlString = entry.fullImageURL, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    podiumInitials
                }
            }
        } else {
            podiumInitials
        }
    }

    private var podiumInitials: some View {
        let initials = String(entry.teamName.prefix(2)).uppercased()
        return Text(initials)
            .font(.system(size: 22, weight: .bold))
            .foregroundStyle(.white)
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

