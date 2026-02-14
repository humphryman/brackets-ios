//
//  ContentView.swift
//  Brackets
//
//  Created by Humberto on 13/02/26.
//

import SwiftUI

struct ContentView: View {
    @State private var viewModel = TournamentsViewModel()
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Categorías")
                                .font(.system(size: 42, weight: .bold))
                                .foregroundStyle(.white)
                            
                            Text("Selecciona una categoría")
                                .font(.system(size: 18))
                                .foregroundStyle(.gray)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                        
                        // Gender Selector
                        GenderSelectorView(selectedGender: $viewModel.selectedGender)
                            .padding(.horizontal, 24)
                        
                        // Tournaments List
                        if viewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(Color(red: 0.8, green: 1.0, blue: 0.4))
                                .scaleEffect(1.5)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 60)
                        } else if let errorMessage = viewModel.errorMessage {
                            VStack(spacing: 16) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 48))
                                    .foregroundStyle(.orange)
                                
                                Text(errorMessage)
                                    .font(.body)
                                    .foregroundStyle(.white)
                                    .multilineTextAlignment(.center)
                                
                                Button("Reintentar") {
                                    Task {
                                        await viewModel.loadTournaments()
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(Color(red: 0.8, green: 1.0, blue: 0.4))
                                .foregroundStyle(.black)
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 60)
                        } else {
                            VStack(spacing: 16) {
                                ForEach(viewModel.filteredTournaments) { tournament in
                                    NavigationLink {
                                        TournamentResultsView(tournament: tournament)
                                    } label: {
                                        TournamentCardView(tournament: tournament)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                        
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

struct GenderSelectorView: View {
    @Binding var selectedGender: Gender
    @Namespace private var animation
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Gender.allCases, id: \.self) { gender in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedGender = gender
                    }
                } label: {
                    Text(gender.displayName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(selectedGender == gender ? .black : .gray)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background {
                            if selectedGender == gender {
                                RoundedRectangle(cornerRadius: 28)
                                    .fill(Color(red: 0.8, green: 1.0, blue: 0.4))
                                    .matchedGeometryEffect(id: "selector", in: animation)
                            }
                        }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(Color(white: 0.15))
        )
        .padding(4)
    }
}

#Preview {
    ContentView()
}
