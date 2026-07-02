//
//  TopStatDetailView.swift
//  Brackets
//

import SwiftUI

struct TopStatDetailView: View {
    let tournament: Tournament
    let stat: String
    let categoryName: String

    @State private var detail: TopStatDetail?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var search = ""
    @State private var selectedTeam = "Todos"
    @Environment(\.dismiss) private var dismiss

    private var players: [PlayerStatEntry] { detail?.players ?? [] }

    private var teams: [String] {
        ["Todos"] + Set(players.map { $0.teamName }).sorted()
    }

    private var filteredPlayers: [PlayerStatEntry] {
        players.filter { entry in
            let nameOK = search.isEmpty || entry.player.fullName.range(of: search, options: [.caseInsensitive, .diacriticInsensitive], locale: .current) != nil
            let teamOK = selectedTeam == "Todos" || entry.teamName == selectedTeam
            return nameOK && teamOK
        }
    }

    private func formatScore(_ score: Double) -> String {
        (detail?.average ?? tournament.usesAverage) ? String(format: "%.1f", score) : String(format: "%.0f", score)
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Group {
            if isLoading {
                AppTheme.LoadingView(message: "Loading stats...")
            } else if let errorMessage {
                AppTheme.ErrorView(message: errorMessage) {
                    Task { await load() }
                }
            } else {
                VStack(spacing: 0) {
                    filterCard
                        .padding(.horizontal, AppTheme.Layout.screenPadding)
                        .padding(.top, AppTheme.Spacing.medium)
                        .padding(.bottom, AppTheme.Spacing.small)

                    if filteredPlayers.isEmpty {
                        AppTheme.EmptyStateView(icon: "person.slash", message: "No hay jugadores.")
                            .frame(maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: AppTheme.Spacing.small) {
                                ForEach(filteredPlayers) { entry in
                                    NavigationLink {
                                        PlayerDetailView(stat: entry, tournamentId: tournament.id)
                                    } label: {
                                        row(entry)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, AppTheme.Layout.screenPadding)
                            .padding(.vertical, AppTheme.Spacing.medium)
                        }
                    }
                }
            }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.Colors.background.ignoresSafeArea())
        .navigationBarHidden(true)
        .task { await load() }
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            Text(categoryName)
                .font(.system(size: 20, weight: .bold))
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
        .padding(.bottom, 8)
    }

    // MARK: - Filter card

    private var filterCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Buscar")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.primaryText)
                TextField("Nombre", text: $search)
                    .font(.system(size: 15))
                    .foregroundStyle(AppTheme.Colors.primaryText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large)
                            .fill(Color(white: 0.12))
                            .stroke(Color(white: 0.3), lineWidth: 1)
                    )
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Equipo")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.primaryText)
                Menu {
                    ForEach(teams, id: \.self) { team in
                        Button(team) { selectedTeam = team }
                    }
                } label: {
                    HStack {
                        Text(selectedTeam)
                            .font(.system(size: 15))
                            .foregroundStyle(AppTheme.Colors.primaryText)
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large)
                            .fill(Color(white: 0.12))
                            .stroke(Color(white: 0.3), lineWidth: 1)
                    )
                }
            }
        }
        .padding(AppTheme.Layout.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large)
                .fill(Color(white: 0.1))
        )
    }

    // MARK: - Row

    private func row(_ entry: PlayerStatEntry) -> some View {
        HStack(spacing: AppTheme.Spacing.medium) {
            Text("\(entry.rank ?? 0)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .frame(width: 28, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.player.fullName)
                    .font(AppTheme.Typography.bodyBold)
                    .foregroundStyle(AppTheme.Colors.primaryText)
                    .lineLimit(1)
                Text(entry.teamName)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .lineLimit(1)
            }

            Spacer()

            Text(formatScore(entry.score))
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AppTheme.Colors.primaryText)
        }
        .cardStyle()
    }

    // MARK: - Data

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            detail = try await APIService.shared.fetchTopStatDetail(for: tournament.id, stat: stat)
            isLoading = false
        } catch {
            errorMessage = "Failed to load stats"
            isLoading = false
        }
    }
}

#Preview {
    NavigationStack {
        TopStatDetailView(
            tournament: Tournament(id: 1, name: "Femenil 2011", gender: .female, teamCount: 8, image: nil),
            stat: "points",
            categoryName: "Puntos"
        )
    }
}
