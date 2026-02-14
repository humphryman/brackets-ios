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
            Color.black
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
                                .fill(Color(white: 0.2))
                                .frame(width: 40, height: 40)
                                .overlay {
                                    Image(systemName: "arrow.left")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(.white)
                                }
                        }
                        
                        Text("Resultados")
                            .font(.system(size: 42, weight: .heavy))
                            .foregroundStyle(.white)
                        
                        Spacer()
                    }
                    
                    // Subtitle
                    Text("Historial de partidos")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundStyle(Color(white: 0.6))
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 24)
                
                // Content
                if viewModel.isLoading {
                    Spacer()
                    HStack {
                        Spacer()
                        ProgressView()
                            .tint(.white)
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
                                .foregroundStyle(.red)
                            Text(errorMessage)
                                .foregroundStyle(.white)
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
                                .foregroundStyle(Color(white: 0.4))
                            Text("No hay partidos registrados")
                                .foregroundStyle(Color(white: 0.6))
                                .font(.system(size: 18))
                        }
                        Spacer()
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 24, pinnedViews: []) {
                            ForEach(viewModel.gamesByDate, id: \.date) { section in
                                VStack(alignment: .leading, spacing: 16) {
                                    // Date header
                                    Text(section.date)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(Color(white: 0.5))
                                        .padding(.horizontal, 24)
                                    
                                    // Games for this date
                                    ForEach(section.games) { game in
                                        GameCardView(game: game)
                                            .padding(.horizontal, 24)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 16)
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
