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
            allTournamentsContent
                .background(Color.black)
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

                            GenderSelectorView(selectedGender: $viewModel.selectedGender)
                                .padding(.horizontal, AppTheme.Layout.extraLarge)

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
        } else {
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(viewModel.tournaments) { tournament in
                        tournamentListCard(for: tournament)
                            .onTapGesture {
                                selectedTournament = tournament
                            }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
            .navigationDestination(item: $selectedTournament) { tournament in
                TournamentContainerView(tournament: tournament)
            }
            .onChange(of: selectedTournament) { _, newValue in
                isBrowsingTournament = newValue != nil
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
                Text(tournament.name)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

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
    @Namespace private var animation
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Gender.allCases, id: \.self) { gender in
                Button {
                    withAnimation(AppTheme.Animation.spring) {
                        selectedGender = gender
                    }
                } label: {
                    Text(gender.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(selectedGender == gender ? AppTheme.Colors.accentText : AppTheme.Colors.secondaryText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background {
                            if selectedGender == gender {
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(AppTheme.Colors.accent)
                                    .matchedGeometryEffect(id: "selector", in: animation)
                            }
                        }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(white: 0.15))
        )
        .padding(4)
    }
}

#Preview {
    ContentView(isBrowsingTournament: .constant(false))
}
