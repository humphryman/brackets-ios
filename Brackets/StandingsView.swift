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

// MARK: - Table layout

/// Shared fixed column widths so the header row and every team row line up.
enum StandingsCol {
    static let rank: CGFloat = 16      // "#"
    static let icon: CGFloat = 16      // desempate (tiebreaker) icon
    static let narrow: CGFloat = 18    // J, G, P
    static let wide: CGFloat = 30      // FAV, CON
    static let last: CGFloat = 50      // AVG / DIF
    static let hSpacing: CGFloat = 4
    static let rowVPadding: CGFloat = 10
}

/// Two-tone surfaces for the standings card: a lighter header band and darker rows.
enum StandingsSurface {
    static let header = Color(white: 0.16)   // title + column-label band (lighter)
    static let rows = Color(white: 0.10)     // team-rows area (darker)
}

/// AVG value rendered as accent-green text on a subtle green-tinted pill.
struct AvgPill: View {
    let value: Double?

    private var text: String {
        guard let value else { return "-" }
        return String(format: "%.3f", value)
    }

    // Green when the average is 1 or above, red when below 1.
    private var color: Color {
        guard let value else { return AppTheme.Colors.neutral }
        return value >= 1 ? AppTheme.Colors.accent : AppTheme.Colors.negative
    }

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(color.opacity(0.15))
            )
    }
}

/// Signed point differential, colored positive/negative/neutral.
struct DiffCell: View {
    let value: Int

    private var color: Color {
        if value > 0 { return AppTheme.Colors.positive }
        if value < 0 { return AppTheme.Colors.negative }
        return AppTheme.Colors.neutral
    }

    var body: some View {
        Text(value > 0 ? "+\(value)" : "\(value)")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }
}

/// Column-label row: `#  EQUIPOS  J  G  P  FAV  CON  AVG/DIF`.
struct StandingsTableHeader: View {
    let usesAverage: Bool

    var body: some View {
        HStack(spacing: StandingsCol.hSpacing) {
            Text("#").frame(width: StandingsCol.rank, alignment: .leading)
            Text("EQUIPOS").frame(maxWidth: .infinity, alignment: .leading)
            Color.clear.frame(width: StandingsCol.icon, height: 0)
            Text("J").frame(width: StandingsCol.narrow)
            Text("G").frame(width: StandingsCol.narrow)
            Text("P").frame(width: StandingsCol.narrow)
            Text("FAV").frame(width: StandingsCol.wide)
            Text("CON").frame(width: StandingsCol.wide)
            Text(usesAverage ? "AVG" : "DIF").frame(width: StandingsCol.last)
        }
        .font(AppTheme.Typography.tinyCaption)
        .foregroundStyle(AppTheme.Colors.secondaryText)
        .textCase(.uppercase)
    }
}

/// One team row inside the standings table. Widths mirror `StandingsTableHeader`.
struct StandingsTableRow: View {
    let position: Int
    let standing: TeamStanding
    let usesAverage: Bool
    var onTiebreakerTap: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: StandingsCol.hSpacing) {
            Text("\(position)")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AppTheme.Colors.primaryText)
                .frame(width: StandingsCol.rank, alignment: .leading)

            Text(standing.teamName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.primaryText)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            Group {
                if standing.tiebreaker != nil, let onTap = onTiebreakerTap {
                    Button(action: onTap) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(width: StandingsCol.icon)

            numeric(standing.total)
            numeric(standing.wins)
            numeric(standing.losses)
            numeric(standing.pointsFor, width: StandingsCol.wide)
            numeric(standing.pointsAgainst, width: StandingsCol.wide)

            Group {
                if usesAverage {
                    AvgPill(value: standing.avg)
                } else {
                    DiffCell(value: standing.pointDifferential)
                }
            }
            .frame(width: StandingsCol.last)
        }
        .padding(.vertical, StandingsCol.rowVPadding)
    }

    private func numeric(_ value: Int, width: CGFloat = StandingsCol.narrow) -> some View {
        Text("\(value)")
            .font(.system(size: 14, weight: .regular))
            .foregroundStyle(AppTheme.Colors.secondaryText)
            .frame(width: width)
    }
}

/// Header row + team rows with hairline dividers. Reused by grouped and flat cases.
struct StandingsTableBody<Row: View>: View {
    let usesAverage: Bool
    let standings: [TeamStanding]
    @ViewBuilder let rowBuilder: (Int, TeamStanding) -> Row

    var body: some View {
        VStack(spacing: 0) {
            // Column-label row — lighter header band, spans full width
            StandingsTableHeader(usesAverage: usesAverage)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(StandingsSurface.header)

            // Team rows — darker surface
            VStack(spacing: 0) {
                ForEach(Array(standings.enumerated()), id: \.element.id) { index, standing in
                    rowBuilder(index, standing)
                    if index < standings.count - 1 {
                        Divider()
                            .overlay(AppTheme.Colors.separator)
                    }
                }
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity)
            .background(StandingsSurface.rows)
        }
    }
}

/// One group rendered as a card: tappable title + chevron, and (when expanded) the table.
struct GroupStandingsCard<Row: View>: View {
    let title: String
    let usesAverage: Bool
    let isExpanded: Bool
    let onToggle: () -> Void
    let standings: [TeamStanding]
    @ViewBuilder let rowBuilder: (Int, TeamStanding) -> Row

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onToggle) {
                HStack {
                    Text(title)
                        .font(AppTheme.Typography.headline)
                        .foregroundStyle(AppTheme.Colors.primaryText)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .background(StandingsSurface.header)
            }
            .buttonStyle(.plain)

            if isExpanded {
                StandingsTableBody(usesAverage: usesAverage, standings: standings, rowBuilder: rowBuilder)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large))
    }
}

struct StandingsView: View {
    let tournament: Tournament
    @State private var bundle: StandingsBundle?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var presentedTiebreaker: Tiebreaker?
    @State private var selectedSubTab: StandingsSubTab
    @State private var expandedGroups: Set<String> = []
    @State private var didInitExpansion = false

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
                    StandingsTableBody(
                        usesAverage: tournament.usesAverage,
                        standings: standings
                    ) { index, standing in
                        standingRow(index: index, standing: standing)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large))
                    .padding(.horizontal, 6)
                case .groups(let groups):
                    ForEach(groups) { group in
                        GroupStandingsCard(
                            title: group.name.capitalized,
                            usesAverage: tournament.usesAverage,
                            isExpanded: expandedGroups.contains(group.id),
                            onToggle: { toggle(group.id) },
                            standings: group.standings
                        ) { index, standing in
                            standingRow(index: index, standing: standing)
                        }
                        .padding(.horizontal, 6)
                    }
                }
            }
            .padding(.top, AppTheme.Spacing.small)
            .padding(.bottom, AppTheme.Layout.large)
        }
    }

    private func loadStandings() async {
        isLoading = true
        errorMessage = nil

        do {
            let loaded = try await APIService.shared.fetchStandings(for: tournament.id)
            bundle = loaded
            if !didInitExpansion, case .groups(let groups) = loaded.result, let first = groups.first {
                expandedGroups = [first.id]
                didInitExpansion = true
            }
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    private func toggle(_ id: String) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            if expandedGroups.contains(id) {
                expandedGroups.remove(id)
            } else {
                expandedGroups.insert(id)
            }
        }
    }

    @ViewBuilder
    private func standingRow(index: Int, standing: TeamStanding) -> some View {
        NavigationLink {
            TeamDetailView(standing: standing, tournamentId: tournament.id, tournamentName: tournament.name, rank: index + 1)
        } label: {
            StandingsTableRow(
                position: index + 1,
                standing: standing,
                usesAverage: tournament.usesAverage,
                onTiebreakerTap: standing.tiebreaker.map { tb in { presentedTiebreaker = tb } }
            )
        }
        .buttonStyle(.plain)
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

#Preview("Table row") {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 0) {
            StandingsTableHeader(usesAverage: true)
            StandingsTableRow(
                position: 1,
                standing: TeamStanding(
                    id: 1, teamName: "San Luis Potosí B", total: 5, wins: 4, losses: 1,
                    pointsFor: 434, pointsAgainst: 386, tie: 0, diff: 48, avg: 1.124,
                    tieBreaker: nil, tiebreaker: nil, teamLogo: nil
                ),
                usesAverage: true
            )
        }
        .padding()
    }
}

#Preview("Group card") {
    ZStack {
        Color.black.ignoresSafeArea()
        let sample = (1...4).map { i in
            TeamStanding(
                id: i, teamName: "Equipo \(i)", total: 5, wins: 5 - i, losses: i - 1,
                pointsFor: 400 + i, pointsAgainst: 380 + i, tie: 0, diff: 20 - i,
                avg: 1.1 - Double(i) / 20.0, tieBreaker: nil, tiebreaker: nil, teamLogo: nil
            )
        }
        GroupStandingsCard(
            title: "Grupo 1", usesAverage: true, isExpanded: true, onToggle: {},
            standings: sample
        ) { index, standing in
            StandingsTableRow(position: index + 1, standing: standing, usesAverage: true)
        }
        .padding()
    }
}

