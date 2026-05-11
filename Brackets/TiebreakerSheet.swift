//
//  TiebreakerSheet.swift
//  Brackets
//
//  Created by Humberto on 10/05/26.
//

import SwiftUI

struct TiebreakerSheet: View {
    let tiebreaker: Tiebreaker

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                    header

                    switch tiebreaker.reason {
                    case .fibaScore:
                        FibaScoreTable(entries: tiebreaker.fibaBreakdown ?? [])
                    case .h2h:
                        H2HList(games: tiebreaker.h2hGames ?? [])
                    case .miniTable:
                        MiniTable(entries: tiebreaker.miniTable ?? [])
                    }
                }
                .padding(.horizontal, AppTheme.Layout.screenPadding)
                .padding(.top, AppTheme.Spacing.large)
                .padding(.bottom, AppTheme.Layout.large)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
            Text("Desempate")
                .font(AppTheme.Typography.bodyBold)
                .foregroundStyle(AppTheme.Colors.accent)
                .textCase(.uppercase)
                .tracking(1)

            Text(subtitle)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.secondaryText)
        }
    }

    private var subtitle: String {
        switch tiebreaker.reason {
        case .fibaScore:  return "Resuelto por puntaje FIBA"
        case .h2h:        return "Resuelto por enfrentamiento directo"
        case .miniTable:  return "Resuelto por mini-tabla"
        }
    }
}

// MARK: - FIBA Score Table

private struct FibaScoreTable: View {
    let entries: [FibaEntry]

    var body: some View {
        if entries.isEmpty {
            Text("Sin datos.")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.secondaryText)
        } else {
            VStack(spacing: 0) {
                // Header row
                HStack {
                    Text("Equipo")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("FIBA")
                        .frame(width: 60, alignment: .trailing)
                }
                .font(AppTheme.Typography.tinyCaption)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .textCase(.uppercase)
                .padding(.vertical, AppTheme.Spacing.small)

                Divider()
                    .background(Color.white.opacity(0.08))

                // Data rows
                ForEach(entries) { entry in
                    HStack {
                        Text(entry.name)
                            .font(AppTheme.Typography.body)
                            .foregroundStyle(AppTheme.Colors.primaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text("\(entry.fibaScore)")
                            .font(AppTheme.Typography.bodyBold)
                            .foregroundStyle(AppTheme.Colors.primaryText)
                            .frame(width: 60, alignment: .trailing)
                    }
                    .padding(.vertical, AppTheme.Spacing.medium)

                    if entry.id != entries.last?.id {
                        Divider()
                            .background(Color.white.opacity(0.08))
                    }
                }
            }
        }
    }
}

// MARK: - Head-to-Head List

private struct H2HList: View {
    let games: [H2HGame]

    var body: some View {
        if games.isEmpty {
            Text("Sin datos.")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.secondaryText)
        } else {
            VStack(spacing: 0) {
                ForEach(games) { game in
                    HStack(spacing: 12) {
                        Text(game.teamA.name)
                            .font(game.teamA.winner ? AppTheme.Typography.bodyBold : AppTheme.Typography.body)
                            .foregroundStyle(game.teamA.winner ? AppTheme.Colors.accent : AppTheme.Colors.primaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity, alignment: .trailing)

                        Text("\(game.teamA.score)")
                            .font(game.teamA.winner ? AppTheme.Typography.bodyBold : AppTheme.Typography.body)
                            .foregroundStyle(game.teamA.winner ? AppTheme.Colors.accent : AppTheme.Colors.primaryText)
                            .frame(minWidth: 32, alignment: .trailing)

                        Text("-")
                            .font(AppTheme.Typography.body)
                            .foregroundStyle(AppTheme.Colors.secondaryText)

                        Text("\(game.teamB.score)")
                            .font(game.teamB.winner ? AppTheme.Typography.bodyBold : AppTheme.Typography.body)
                            .foregroundStyle(game.teamB.winner ? AppTheme.Colors.accent : AppTheme.Colors.primaryText)
                            .frame(minWidth: 32, alignment: .leading)

                        Text(game.teamB.name)
                            .font(game.teamB.winner ? AppTheme.Typography.bodyBold : AppTheme.Typography.body)
                            .foregroundStyle(game.teamB.winner ? AppTheme.Colors.accent : AppTheme.Colors.primaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, AppTheme.Spacing.medium)

                    if game.id != games.last?.id {
                        Divider()
                            .background(Color.white.opacity(0.08))
                    }
                }
            }
        }
    }
}

// MARK: - Mini Table

private struct MiniTable: View {
    let entries: [MiniTableEntry]

    var body: some View {
        EmptyView() // implemented in Task 5
    }
}

// MARK: - Preview

#Preview("FIBA Score") {
    TiebreakerSheet(tiebreaker: Tiebreaker(
        groupIndex: 1,
        bucketId: 2,
        bucketSize: 2,
        reason: .fibaScore,
        fibaBreakdown: [
            FibaEntry(id: 8, name: "Lakers", fibaScore: 7),
            FibaEntry(id: 12, name: "Heat", fibaScore: 6)
        ],
        h2hGames: nil,
        miniTable: nil
    ))
}
