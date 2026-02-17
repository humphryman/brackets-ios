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
                AppTheme.Colors.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: AppTheme.Layout.extraLarge) {
                        // Header
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                            Text("Categorías")
                                .font(.system(size: 42, weight: .bold))
                                .foregroundStyle(AppTheme.Colors.primaryText)
                            
                            Text("Selecciona una categoría")
                                .font(AppTheme.Typography.headline)
                                .foregroundStyle(AppTheme.Colors.secondaryText)
                        }
                        .padding(.horizontal, AppTheme.Layout.extraLarge)
                        .padding(.top, AppTheme.Layout.large)
                        
                        // Gender Selector
                        GenderSelectorView(selectedGender: $viewModel.selectedGender)
                            .padding(.horizontal, AppTheme.Layout.extraLarge)
                        
                        // Tournaments List
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
                    withAnimation(AppTheme.Animation.spring) {
                        selectedGender = gender
                    }
                } label: {
                    Text(gender.displayName)
                        .font(AppTheme.Typography.headline)
                        .foregroundStyle(selectedGender == gender ? AppTheme.Colors.accentText : AppTheme.Colors.secondaryText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background {
                            if selectedGender == gender {
                                RoundedRectangle(cornerRadius: 28)
                                    .fill(AppTheme.Colors.accent)
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
