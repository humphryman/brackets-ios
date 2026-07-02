//
//  ContentView.swift
//  Brackets
//
//  Created by Humberto on 13/02/26.
//

import SwiftUI

struct ContentView: View {
    var leagueName: String = "Categorías"
    var embedded: Bool = false
    var sport: String? = nil
    @Binding var isBrowsingTournament: Bool
    @State private var viewModel = TournamentsViewModel()
    @State private var selectedTournament: Tournament?

    var body: some View {
        if embedded {
            ZStack {
                Color.black.ignoresSafeArea()
                allTournamentsContent
            }
            .task {
                await viewModel.loadTournaments()
            }
        } else {
            NavigationStack {
                ZStack {
                    AppTheme.Colors.background
                        .ignoresSafeArea()

                    ScrollView {
                        VStack(alignment: .leading, spacing: AppTheme.Layout.extraLarge) {
                            // Header
                            VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                                Text(leagueName)
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundStyle(AppTheme.Colors.primaryText)

                                Text("Selecciona una categoría")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(AppTheme.Colors.secondaryText)
                            }
                            .padding(.horizontal, AppTheme.Layout.extraLarge)
                            .padding(.top, AppTheme.Layout.large)

                            if viewModel.showsGenderTabs {
                                GenderSelectorView(
                                    selectedGender: $viewModel.selectedGender,
                                    genders: viewModel.availableGenders
                                )
                                .padding(.horizontal, AppTheme.Layout.extraLarge)
                            }

                            tournamentsContent

                            Spacer(minLength: 40)
                        }
                    }
                }
                .task {
                    await viewModel.loadTournaments()
                }
            }
        }
    }

    @ViewBuilder
    private var allTournamentsContent: some View {
        if viewModel.isLoading {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(AppTheme.Colors.loading)
                .scaleEffect(1.5)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage = viewModel.errorMessage {
            AppTheme.ErrorView(message: errorMessage) {
                Task {
                    await viewModel.loadTournaments()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.tournaments.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "trophy")
                    .font(.system(size: 40))
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                Text("No hay categorías disponibles")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(spacing: 16) {
                    if viewModel.showsGenderTabs {
                        GenderSelectorView(
                            selectedGender: $viewModel.selectedGender,
                            genders: viewModel.availableGenders
                        )
                    }

                    ForEach(viewModel.filteredTournaments) { tournament in
                        tournamentListCard(for: tournament)
                            .onTapGesture {
                                selectedTournament = tournament
                                isBrowsingTournament = true
                            }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
            .navigationDestination(
                item: Binding(
                    get: { selectedTournament },
                    set: { newValue in
                        selectedTournament = newValue
                        isBrowsingTournament = newValue != nil
                    }
                )
            ) { tournament in
                TournamentContainerView(tournament: tournament)
            }
        }
    }

    private func tournamentListCard(for tournament: Tournament) -> some View {
        VStack(spacing: 0) {
            // Image area
            ZStack(alignment: .topTrailing) {
                if let imageURLString = tournament.fullImageURL, let url = URL(string: imageURLString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 140)
                                .clipped()
                        case .failure:
                            tournamentImageFallback(for: tournament)
                        case .empty:
                            ZStack {
                                Color(white: 0.15)
                                ProgressView().tint(.white)
                            }
                            .frame(height: 140)
                        @unknown default:
                            tournamentImageFallback(for: tournament)
                        }
                    }
                } else {
                    tournamentImageFallback(for: tournament)
                }

                // Champion overlay — dims image and centers winner text
                if let winner = tournament.winner {
                    ZStack {
                        Color.black.opacity(0.65)

                        VStack(spacing: 2) {
                            Text(winner.teamName.uppercased())
                                .font(.system(size: 22, weight: .heavy))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                            Text("CAMPEÓN")
                                .font(.system(size: 18, weight: .heavy))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 16)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                // Stage badge — top right
                if let stage = tournament.stage {
                    Text(stage)
                        .font(.system(size: 11, weight: .bold))
                        .italic()
                        .foregroundStyle(AppTheme.Colors.accentText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(AppTheme.Colors.accent))
                        .padding(10)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 140)
            .clipped()

            // Info area
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    Text(tournament.name)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Spacer()

                    if tournament.hasLiveGames {
                        LiveGamesIndicator()
                    }
                }

                HStack {
                    if let dateRange = tournament.formattedDateRange {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                                .font(.system(size: 12))
                            Text(dateRange)
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundStyle(Color(white: 0.55))
                    }

                    Spacer()

                    HStack(spacing: 5) {
                        Text("Ver categoría")
                            .font(.system(size: 13, weight: .semibold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(AppTheme.Colors.accentText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(AppTheme.Colors.accent))
                }
            }
            .padding(14)
        }
        .background(Color(white: 0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .contentShape(RoundedRectangle(cornerRadius: 16))
    }

    private func tournamentImageFallback(for tournament: Tournament) -> some View {
        ZStack {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.15, green: 0.2, blue: 0.35),
                            Color(red: 0.1, green: 0.15, blue: 0.25)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text(String(tournament.name.prefix(2)).uppercased())
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(.white.opacity(0.15))
        }
        .frame(height: 140)
    }

    @ViewBuilder
    private var tournamentsContent: some View {
        if viewModel.isLoading {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(AppTheme.Colors.loading)
                .scaleEffect(1.5)
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
        } else if let errorMessage = viewModel.errorMessage {
            AppTheme.ErrorView(message: errorMessage) {
                Task {
                    await viewModel.loadTournaments()
                }
            }
            .padding(.top, 60)
        } else if viewModel.filteredTournaments.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "trophy")
                    .font(.system(size: 40))
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                Text("No hay categorías disponibles")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 60)
        } else {
            VStack(spacing: AppTheme.Layout.itemSpacing) {
                ForEach(viewModel.filteredTournaments) { tournament in
                    NavigationLink {
                        TournamentContainerView(tournament: tournament)
                    } label: {
                        TournamentCardView(tournament: tournament)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, AppTheme.Layout.extraLarge)
        }
    }
}

struct GenderSelectorView: View {
    @Binding var selectedGender: Gender
    var genders: [Gender] = Gender.allCases

    var body: some View {
        HStack(spacing: AppTheme.Spacing.small) {
            ForEach(genders, id: \.self) { gender in
                let isSelected = selectedGender == gender
                Button {
                    withAnimation(AppTheme.Animation.spring) {
                        selectedGender = gender
                    }
                } label: {
                    Text(gender.displayName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(isSelected ? AppTheme.Colors.accentText : AppTheme.Colors.secondaryText)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            Capsule().fill(isSelected ? AppTheme.Colors.accent : Color(white: 0.15))
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }
}

private struct LiveGamesIndicator: View {
    @State private var pulse: Bool = false

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(AppTheme.Colors.live)
                .frame(width: 6, height: 6)
                .opacity(pulse ? 1.0 : 0.4)
                .animation(
                    .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                    value: pulse
                )

            Text("JUEGOS EN VIVO")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.live)
        }
        .onAppear { pulse = true }
    }
}

#Preview {
    ContentView(isBrowsingTournament: .constant(false))
}
