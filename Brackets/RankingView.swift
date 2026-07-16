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
}

/// Full-screen final ranking list. Receives pre-fetched data — no loading state.
struct RankingView: View {
    let response: RankingResponse
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AppTheme.Colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                columnHeader
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(response.ranking.enumerated()), id: \.element.id) { index, entry in
                            RankingRow(entry: entry, striped: index.isMultiple(of: 2))
                        }
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Ranking Final")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AppTheme.Colors.primaryText)
                Text(response.tournamentName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 8)
            Button {
                dismiss()
            } label: {
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 36, height: 36)
                    .overlay {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppTheme.Colors.primaryText)
                    }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AppTheme.Layout.screenPadding)
        .padding(.top, 12)
        .padding(.bottom, 16)
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
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(AppTheme.Colors.secondaryText)
        .padding(.horizontal, AppTheme.Layout.screenPadding)
        .padding(.vertical, 10)
        .background(StandingsSurface.header)
    }
}

private struct RankingRow: View {
    let entry: RankingEntry
    let striped: Bool

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
        .padding(.horizontal, AppTheme.Layout.screenPadding)
        .padding(.vertical, RankingCol.rowVPadding)
        .background(striped ? Color(white: 0.13) : StandingsSurface.rows)
    }
}

/// Full-width navy pill button that opens the final ranking.
struct RankingButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 15, weight: .semibold))
                Text("Ranking Final")
                    .font(.system(size: 15, weight: .bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color(red: 26 / 255, green: 23 / 255, blue: 211 / 255), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview("Ranking view") {
    RankingView(response: RankingResponse(
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

#Preview("Ranking button") {
    ZStack {
        Color.black.ignoresSafeArea()
        RankingButton { }
            .padding()
    }
}
