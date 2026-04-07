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
    @State private var selectedCustomer: Customer?
    @State private var isExpanded = false
    @State private var showContent = false
    @State private var dragOffset: CGFloat = 0
    @State private var cardFrame: CGRect = .zero
    @State private var loadedImages: [Int: Image] = [:]
    @State private var isBrowsingTournament = false
    @State private var showHeader = false
    @State private var logoRotation: Double = 0

    private let expandSpring = Animation.spring(response: 2.0, dampingFraction: 0.85)

    var body: some View {
        GeometryReader { geo in
            let screenWidth = geo.size.width
            let screenHeight = geo.size.height

            ZStack(alignment: .topLeading) {
                AppTheme.Colors.background
                    .ignoresSafeArea()

                // Layer 1 — league list
                leagueListContent
                    .offset(x: isExpanded ? -screenWidth : 0)

                // Layer 2 — expanded overlay (slides in from right)
                if let customer = selectedCustomer {
                    expandedOverlay(for: customer, screenWidth: screenWidth, screenHeight: screenHeight)
                        .offset(x: isExpanded ? 0 : screenWidth)
                }
            }
            .coordinateSpace(name: "root")
        }
    }

    // MARK: - League List

    private var leagueListContent: some View {
        ZStack {
            if isLoading {
                ZStack {
                    Color.black.ignoresSafeArea()
                    Image("AppLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .rotation3DEffect(
                            .degrees(logoRotation),
                            axis: (x: 0, y: 1, z: 0)
                        )
                        .onAppear {
                            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                                logoRotation = 360
                            }
                        }
                }
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

                            Text("Selecciona una liga para ver sus categorias.")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(AppTheme.Colors.secondaryText)
                        }
                        .padding(.horizontal, AppTheme.Layout.extraLarge)
                        .padding(.top, AppTheme.Layout.large)

                        // League cards
                        VStack(spacing: AppTheme.Layout.itemSpacing) {
                            ForEach(customers) { customer in
                                leagueCard(for: customer)
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

    // MARK: - League Card

    private func leagueCard(for customer: Customer) -> some View {
        VStack(spacing: 0) {
            // Image area
            ZStack(alignment: .topTrailing) {
                GeometryReader { geometry in
                    cardImage(for: customer, width: geometry.size.width, height: geometry.size.height)
                }

                // Sport badge — top right
                if let sport = customer.sport {
                    Text(sport.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AppTheme.Colors.accentText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(AppTheme.Colors.accent))
                        .padding(10)
                }
            }
            .frame(height: 140)
            .clipped()

            // Info area
            Text(customer.name)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(14)
        }
        .background(Color(white: 0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .contentShape(Rectangle())
        .onTapGesture {
            selectCustomer(customer)
        }
    }

    // MARK: - Expanded Overlay

    private func expandedOverlay(for customer: Customer, screenWidth: CGFloat, screenHeight: CGFloat) -> some View {
        let bannerHeight = screenHeight * 0.25

        return ZStack(alignment: .topLeading) {
            // Background fades in behind the banner
            Color.black
                .ignoresSafeArea()
                .opacity(isExpanded ? 1 : 0)

            // Content
            let headerHeight: CGFloat = 64
            if showContent {
                NavigationStack {
                    ContentView(leagueName: customer.name, embedded: true, sport: customer.sport, isBrowsingTournament: $isBrowsingTournament)
                        .toolbar(.hidden)
                        .padding(.top, headerHeight)
                }
                .background(Color.black.ignoresSafeArea())
                .ignoresSafeArea()
            }

            // Animated banner — starts at card position, animates to top, then collapses
            let expandedPadding: CGFloat = 8
            let expandedWidth = screenWidth - expandedPadding * 2
            cardBanner(for: customer)
                .frame(
                    width: isExpanded ? expandedWidth : cardFrame.width,
                    height: isExpanded ? (showHeader ? headerHeight : bannerHeight) : cardFrame.height
                )
                .clipShape(RoundedRectangle(cornerRadius: showHeader ? 0 : 28))
                .offset(
                    x: isExpanded ? (showHeader ? 0 : expandedPadding) : cardFrame.minX,
                    y: isExpanded ? (showHeader ? 0 : expandedPadding) : cardFrame.minY
                )
                .opacity(isBrowsingTournament ? 0 : 1)
                .allowsHitTesting(false)

            // Header bar — back button + title matching first screen style
            if showContent && !isBrowsingTournament {
                ZStack {
                    Text(customer.name)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(AppTheme.Colors.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)

                    HStack {
                        Button {
                            dismissCustomer()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(12)
                                .background(Circle().fill(.black.opacity(0.15)))
                        }
                        Spacer()
                    }
                }
                .padding(.horizontal, AppTheme.Layout.extraLarge)
                .padding(.top, 10)
                .padding(.bottom, 12)
                .transition(.opacity)
            }
        }
        .offset(x: dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    guard value.startLocation.x < 40 else { return }
                    dragOffset = max(0, value.translation.width)
                }
                .onEnded { value in
                    guard value.startLocation.x < 40 else { return }
                    let shouldDismiss = value.translation.width > 120
                        || value.predictedEndTranslation.width > 300
                    if shouldDismiss {
                        dismissCustomer()
                    } else {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            dragOffset = 0
                        }
                    }
                }
        )
    }

    // MARK: - Card Banner (animated from card → top)

    private func cardBanner(for customer: Customer) -> some View {
        ZStack(alignment: .bottomLeading) {
            // Background image — use pre-loaded image for instant display
            GeometryReader { geometry in
                if let img = loadedImages[customer.id] {
                    img
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                } else {
                    cardImage(for: customer, width: geometry.size.width, height: geometry.size.height)
                }
            }
            .opacity(showHeader ? 0 : 1)

            // Dark overlay gradient
            cardGradient
                .opacity(showHeader ? 0 : 1)

            // Sport badge — top right
            sportBadge(for: customer)
                .opacity(showHeader ? 0 : 1)

            // Bottom: title + arrow (fades out when expanded/header)
            VStack {
                Spacer()
                HStack(alignment: .bottom) {
                    Text(customer.name.uppercased())
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)

                    Spacer()

                    arrowCircle
                        .opacity(isExpanded ? 0 : 1)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .opacity(showHeader ? 0 : 1)
        }
        .background(showHeader ? Color.black : Color.clear)
    }

    // MARK: - Shared Card Visuals

    private var cardGradient: some View {
        LinearGradient(
            colors: [
                .black.opacity(0.7),
                .black.opacity(0.4),
                .clear
            ],
            startPoint: .bottom,
            endPoint: .center
        )
    }

    @ViewBuilder
    private func sportBadge(for customer: Customer) -> some View {
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
    }

    private var arrowCircle: some View {
        Circle()
            .fill(AppTheme.Colors.accent)
            .frame(width: 40, height: 40)
            .overlay {
                Image(systemName: "arrow.right")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(AppTheme.Colors.accentText)
            }
    }

    @ViewBuilder
    private func cardImage(for customer: Customer, width: CGFloat, height: CGFloat) -> some View {
        if let logoUrl = customer.logoUrl, let url = URL(string: logoUrl) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: width, height: height)
                        .clipped()
                        .onAppear { loadedImages[customer.id] = image }
                case .failure:
                    fallbackBackground(for: customer)
                case .empty:
                    ZStack {
                        Color(white: 0.15)
                        ProgressView()
                            .tint(.white)
                    }
                @unknown default:
                    fallbackBackground(for: customer)
                }
            }
        } else {
            fallbackBackground(for: customer)
        }
    }

    // MARK: - Actions

    private func selectCustomer(_ customer: Customer) {
        AppConfig.API.baseURL = customer.url
        selectedCustomer = customer
        showHeader = true
        showContent = true
        withAnimation(.easeInOut(duration: 0.3)) {
            isExpanded = true
        }
    }

    private func dismissCustomer() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isExpanded = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showHeader = false
            showContent = false
            dragOffset = 0
            selectedCustomer = nil
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

    // MARK: - Helpers

    private func fallbackBackground(for customer: Customer) -> some View {
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
