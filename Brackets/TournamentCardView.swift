//
//  TournamentCardView.swift
//  Brackets
//
//  Created by Humberto on 13/02/26.
//

import SwiftUI

struct TournamentCardView: View {
    let tournament: Tournament
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomLeading) {
                // Background image
                if let imageURLString = tournament.fullImageURL, let url = URL(string: imageURLString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .clipped()
                        case .failure(let error):
                            VStack {
                                defaultBackground
                                Text("Failed to load")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                            .onAppear {
                                print("❌ Failed to load image from: \(imageURLString)")
                                print("Error: \(error)")
                            }
                        case .empty:
                            ZStack {
                                Color(white: 0.15)
                                ProgressView()
                                    .tint(.white)
                            }
                            .onAppear {
                                print("📥 Loading image from: \(imageURLString)")
                            }
                        @unknown default:
                            defaultBackground
                        }
                    }
                } else {
                    defaultBackground
                        .onAppear {
                            if let rawImage = tournament.image {
                                print("⚠️ Invalid URL - Raw: \(rawImage), Full: \(tournament.fullImageURL ?? "nil")")
                            } else {
                                print("ℹ️ No image provided for tournament: \(tournament.name)")
                            }
                        }
                }
                
                // Dark overlay gradient for text readability
                LinearGradient(
                    colors: [
                        .black.opacity(0.7),
                        .black.opacity(0.4),
                        .clear
                    ],
                    startPoint: .bottom,
                    endPoint: .center
                )
                
                // Content overlay
                VStack {
                    Spacer()

                    // Bottom content
                    HStack(alignment: .bottom) {
                        // Tournament name
                        Text(tournament.name.uppercased())
                            .font(.system(size: 22, weight: .heavy))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)

                        Spacer()

                        // Arrow button
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
    
    private var defaultBackground: some View {
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
    }
}

#Preview {
    VStack(spacing: 20) {
        TournamentCardView(
            tournament: Tournament(
                id: 1,
                name: "Juvenil Varonil",
                gender: .male,
                teamCount: 8,
                image: nil
            )
        )
        
        TournamentCardView(
            tournament: Tournament(
                id: 2,
                name: "Testing Category",
                gender: .male,
                teamCount: 6,
                image: nil
            )
        )
    }
    .padding()
    .background(.black)
}
