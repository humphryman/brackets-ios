//
//  TournamentResultsView.swift
//  Brackets
//
//  Created by Humberto on 13/02/26.
//

import SwiftUI

struct TournamentResultsView: View {
    let tournament: Tournament
    @State private var viewModel = GamesViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Background
            AppTheme.Colors.background
                .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    // Back button and Title on same line
                    HStack(alignment: .center, spacing: 12) {
                        Button {
                            dismiss()
                        } label: {
                            Circle()
                                .fill(AppTheme.Colors.cardBackground)
                                .frame(width: 40, height: 40)
                                .overlay {
                                    Image(systemName: "arrow.left")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(AppTheme.Colors.primaryText)
                                }
                        }
                        
                        Text("Resultados")
                            .font(AppTheme.Typography.largeTitle)
                            .foregroundStyle(AppTheme.Colors.primaryText)
                        
                        Spacer()
                    }
                    
                    // Subtitle
                    Text("Historial de partidos")
                        .font(AppTheme.Typography.headline)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }
                .padding(.horizontal, AppTheme.Layout.extraLarge)
                .padding(.top, AppTheme.Layout.large)
                .padding(.bottom, AppTheme.Layout.extraLarge)
                
                // Content
                if viewModel.isLoading {
                    Spacer()
                    HStack {
                        Spacer()
                        ProgressView()
                            .tint(AppTheme.Colors.loading)
                        Spacer()
                    }
                    Spacer()
                } else if let errorMessage = viewModel.errorMessage {
                    Spacer()
                    HStack {
                        Spacer()
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 48))
                                .foregroundStyle(.orange)
                            Text(errorMessage)
                                .foregroundStyle(AppTheme.Colors.primaryText)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        Spacer()
                    }
                    Spacer()
                } else if viewModel.gamesByDate.isEmpty {
                    Spacer()
                    HStack {
                        Spacer()
                        VStack(spacing: 16) {
                            Image(systemName: "sportscourt")
                                .font(.system(size: 48))
                                .foregroundStyle(AppTheme.Colors.secondaryText)
                            Text("No hay partidos registrados")
                                .foregroundStyle(AppTheme.Colors.secondaryText)
                                .font(AppTheme.Typography.headline)
                        }
                        Spacer()
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: AppTheme.Layout.extraLarge, pinnedViews: []) {
                            ForEach(viewModel.gamesByDate, id: \.date) { section in
                                VStack(alignment: .leading, spacing: AppTheme.Layout.itemSpacing) {
                                    // Date header
                                    Text(section.date)
                                        .font(AppTheme.Typography.bodyBold)
                                        .foregroundStyle(AppTheme.Colors.secondaryText)
                                        .padding(.horizontal, AppTheme.Layout.extraLarge)
                                    
                                    // Games for this date
                                    ForEach(section.games) { game in
                                        GameCardView(game: game)
                                            .padding(.horizontal, AppTheme.Layout.extraLarge)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, AppTheme.Layout.itemSpacing)
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .task {
            await viewModel.loadGames(for: tournament.id)
        }
    }
}

#Preview {
    TournamentResultsView(
        tournament: Tournament(
            id: 1,
            name: "Juvenil Varonil",
            gender: .male,
            teamCount: 8,
            image: nil
        )
    )
}
