//
//  TeamDetailView.swift
//  Brackets
//

import SwiftUI

struct TeamDetailView: View {
    let standing: TeamStanding
    let tournamentId: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AppTheme.Colors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
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

                    Text(standing.teamName)
                        .font(AppTheme.Typography.largeTitle)
                        .foregroundStyle(AppTheme.Colors.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Spacer()
                }
                .padding(.horizontal, AppTheme.Layout.extraLarge)
                .padding(.top, AppTheme.Layout.large)
                .padding(.bottom, AppTheme.Layout.itemSpacing)

                ScrollView {
                    VStack(spacing: AppTheme.Spacing.large) {
                        teamHeroCard
                    }
                    .padding(.horizontal, AppTheme.Layout.screenPadding)
                    .padding(.bottom, AppTheme.Layout.large)
                }
            }
        }
        .navigationBarHidden(true)
    }

    // MARK: - Team Hero Card

    private var teamHeroCard: some View {
        ZStack(alignment: .bottom) {
            // Background team image
            if let imageURL = standing.fullImageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 200)
                            .clipped()
                    default:
                        placeholderBackground
                    }
                }
            } else {
                placeholderBackground
            }

            // Gradient overlay for readability
            LinearGradient(
                colors: [.clear, Color.black.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 120)

            // Team name overlay (top-left)
            VStack {
                HStack {
                    Text(standing.teamName)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(AppTheme.Colors.accent)
                        .shadow(color: .black.opacity(0.6), radius: 4, x: 0, y: 2)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                Spacer()
            }

            // Bottom bar overlay with wins / losses
            HStack(spacing: 24) {
                VStack(spacing: 4) {
                    Text("\(standing.wins)")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(AppTheme.Colors.accent)
                    Text("Wins")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color(white: 0.6))
                }

                Rectangle()
                    .fill(Color(white: 0.4))
                    .frame(width: 1, height: 40)

                VStack(spacing: 4) {
                    Text("\(standing.losses)")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(Color.red)
                    Text("Losses")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color(white: 0.6))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.black.opacity(0.6))
        }
        .frame(height: 200)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large)
                .stroke(Color(white: 1.0).opacity(0.18), lineWidth: 1)
        )
    }

    private var placeholderBackground: some View {
        Rectangle()
            .fill(Color(white: 0.15))
            .frame(maxWidth: .infinity)
            .frame(height: 200)
            .overlay(
                Image(systemName: "sportscourt")
                    .font(.system(size: 48))
                    .foregroundStyle(Color(white: 0.3))
            )
    }
}
