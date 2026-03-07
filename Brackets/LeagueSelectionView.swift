//
//  LeagueSelectionView.swift
//  Brackets
//
//  Created by Humberto on 06/03/26.
//

import SwiftUI

struct LeagueSelectionView: View {
    @State private var customers: [Customer] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Colors.background
                    .ignoresSafeArea()

                if isLoading {
                    AppTheme.LoadingView(message: "Cargando ligas...")
                } else if let errorMessage {
                    AppTheme.ErrorView(message: errorMessage) {
                        Task { await loadCustomers() }
                    }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: AppTheme.Layout.extraLarge) {
                            // Header
                            VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                                Text("Ligas Activas")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundStyle(AppTheme.Colors.primaryText)

                                Text("Selecciona una liga para ver sus torneos")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(AppTheme.Colors.secondaryText)
                            }
                            .padding(.horizontal, AppTheme.Layout.extraLarge)
                            .padding(.top, AppTheme.Layout.large)

                            // League cards
                            VStack(spacing: AppTheme.Layout.itemSpacing) {
                                ForEach(customers) { customer in
                                    NavigationLink {
                                        ContentView()
                                            .onAppear {
                                                AppConfig.API.baseURL = customer.url
                                            }
                                    } label: {
                                        LeagueCardView(customer: customer)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, AppTheme.Layout.extraLarge)

                            Spacer(minLength: 40)
                        }
                    }
                }
            }
            .task {
                await loadCustomers()
            }
        }
    }

    private func loadCustomers() async {
        isLoading = true
        errorMessage = nil
        do {
            customers = try await APIService.shared.fetchCustomers()
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}

// MARK: - League Card

private struct LeagueCardView: View {
    let customer: Customer

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomLeading) {
                // Background
                if let logoUrl = customer.logoUrl, let url = URL(string: logoUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .clipped()
                        case .failure:
                            fallbackBackground
                        case .empty:
                            ZStack {
                                Color(white: 0.15)
                                ProgressView()
                                    .tint(.white)
                            }
                        @unknown default:
                            fallbackBackground
                        }
                    }
                } else {
                    fallbackBackground
                }

                // Dark overlay gradient
                LinearGradient(
                    colors: [
                        .black.opacity(0.7),
                        .black.opacity(0.4),
                        .clear
                    ],
                    startPoint: .bottom,
                    endPoint: .center
                )

                // Sport badge — top right
                if let sport = customer.sport {
                    VStack {
                        HStack {
                            Spacer()
                            Text(sport.uppercased())
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(AppTheme.Colors.accentText)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(AppTheme.Colors.accent))
                        }
                        Spacer()
                    }
                    .padding(16)
                }

                // Bottom content
                VStack {
                    Spacer()
                    HStack(alignment: .bottom) {
                        Text(customer.name.uppercased())
                            .font(.system(size: 22, weight: .heavy))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)

                        Spacer()

                        Circle()
                            .fill(AppTheme.Colors.accent)
                            .frame(width: 40, height: 40)
                            .overlay {
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(AppTheme.Colors.accentText)
                            }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
        }
        .aspectRatio(2.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 28))
    }

    private var fallbackBackground: some View {
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

            Text(initials(for: customer.name))
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(.white.opacity(0.2))
        }
    }

    private func initials(for name: String) -> String {
        let words = name.split(separator: " ")
        let letters = words.prefix(2).compactMap { $0.first }
        return String(letters).uppercased()
    }
}

#Preview {
    LeagueSelectionView()
}
