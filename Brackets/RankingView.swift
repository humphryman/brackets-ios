//
//  RankingView.swift
//  Brackets
//

import SwiftUI

/// Fixed column widths so the header row and every ranking row line up.
private enum RankingCol {
    static let place: CGFloat = 28
    static let bracket: CGFloat = 64
    static let result: CGFloat = 96
    static let hSpacing: CGFloat = 10
    static let rowVPadding: CGFloat = 12
    /// Inset from the card edge, matching `StandingsTableBody`.
    static let hPadding: CGFloat = 14
    /// Gap between the card and the screen edge, matching `GroupStandingsCard`.
    static let cardInset: CGFloat = 6
}

/// Final ranking table — column header plus scrolling rows. Receives pre-fetched data,
/// so it has no loading state of its own. Lives inside the Standings tab bar.
struct RankingTable: View {
    let response: RankingResponse

    var body: some View {
        ScrollView {
            // The header rides along as a pinned section header, so the column
            // labels stay put on a long ranking while the card keeps its corners.
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                Section {
                    ForEach(Array(response.ranking.enumerated()), id: \.element.id) { index, entry in
                        RankingRow(entry: entry)
                        if index < response.ranking.count - 1 {
                            Divider()
                                .overlay(AppTheme.Colors.separator)
                                .padding(.horizontal, RankingCol.hPadding)
                        }
                    }
                } header: {
                    columnHeader
                }
            }
            .background(StandingsSurface.rows)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large))
            .padding(.horizontal, RankingCol.cardInset)
            .padding(.top, AppTheme.Spacing.small)
            .padding(.bottom, AppTheme.Layout.large)
        }
    }

    private var columnHeader: some View {
        HStack(spacing: RankingCol.hSpacing) {
            Text("#")
                .frame(width: RankingCol.place, alignment: .leading)
            Text("EQUIPO")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("BRACKET")
                .frame(width: RankingCol.bracket, alignment: .leading)
            Text("RESULTADO")
                .frame(width: RankingCol.result, alignment: .leading)
        }
        .font(AppTheme.Typography.tinyCaption)
        .foregroundStyle(AppTheme.Colors.gray400)
        .textCase(.uppercase)
        .padding(.horizontal, RankingCol.hPadding)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(StandingsSurface.header)
    }
}

private struct RankingRow: View {
    let entry: RankingEntry

    var body: some View {
        HStack(spacing: RankingCol.hSpacing) {
            Text("\(entry.place)")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .frame(width: RankingCol.place, alignment: .leading)

            Text(entry.teamName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.primaryText)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(entry.bracketName ?? "")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.Colors.primaryText)
                .frame(width: RankingCol.bracket, alignment: .leading)

            Text(entry.stageLabel ?? "")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.Colors.primaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .frame(width: RankingCol.result, alignment: .leading)
        }
        .padding(.horizontal, RankingCol.hPadding)
        .padding(.vertical, RankingCol.rowVPadding)
    }
}

#Preview("Ranking table") {
    RankingTable(response: RankingResponse(
        tournamentId: 45,
        tournamentName: "Femenil 2008-09",
        available: true,
        ranking: [
            RankingEntry(place: 1, teamId: 417, teamSeasonId: 890, teamName: "Gladiadores Valle", teamLogo: nil, bracketName: "Gold", stageLabel: "Campeón"),
            RankingEntry(place: 2, teamId: 436, teamSeasonId: 909, teamName: "Pingüinos Sierra", teamLogo: nil, bracketName: "Gold", stageLabel: "Subcampeón"),
            RankingEntry(place: 3, teamId: 453, teamSeasonId: 926, teamName: "Cometas Azteca", teamLogo: nil, bracketName: "Gold", stageLabel: "3er Lugar"),
            RankingEntry(place: 9, teamId: 413, teamSeasonId: 886, teamName: "Águilas Continental", teamLogo: nil, bracketName: "Silver", stageLabel: "Campeón"),
            RankingEntry(place: 17, teamId: 500, teamSeasonId: 950, teamName: "Rayos Valle", teamLogo: nil, bracketName: "Silver", stageLabel: "Octavos de Final"),
            RankingEntry(place: 25, teamId: 420, teamSeasonId: 893, teamName: "Cometas Cumbres", teamLogo: nil, bracketName: "Bronze", stageLabel: "Campeón"),
        ]
    ))
}
