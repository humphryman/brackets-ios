//
//  GameCardView.swift
//  Brackets
//
//  Created by Humberto on 13/02/26.
//

import SwiftUI

struct GameCardView: View {
    let game: Game
    
    // Accent color (lime green from design)
    private let accentColor = Color(red: 0.8, green: 1.0, blue: 0.4)
    
    var body: some View {
        ZStack {
            // Card background
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(white: 0.12))
            
            if game.homeTeam == nil || game.awayTeam == nil {
                // Show placeholder when team data is missing
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 24))
                        .foregroundStyle(Color(white: 0.4))
                    Text("Datos del partido no disponibles")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color(white: 0.5))
                }
                .padding()
            } else {
                HStack(spacing: 8) {
                    // Home team (left side)
                    if let homeTeam = game.homeTeam {
                        TeamView(
                            team: homeTeam,
                            isWinner: game.winner?.id == homeTeam.id
                        )
                        .frame(maxWidth: .infinity)
                    }
                    
                    // Center - Score
                    VStack(spacing: 8) {
                        HStack(alignment: .center, spacing: 8) {
                            // Home score
                            Text(game.homeScore.map { "\($0)" } ?? "0")
                                .font(.system(size: 36, weight: .heavy))
                                .foregroundStyle(game.winner?.id == game.homeTeam?.id ? accentColor : Color(white: 0.5))
                                .frame(minWidth: 30)
                            
                            // Separator
                            Text(":")
                                .font(.system(size: 36, weight: .heavy))
                                .foregroundStyle(Color(white: 0.3))
                            
                            // Away score
                            Text(game.awayScore.map { "\($0)" } ?? "0")
                                .font(.system(size: 36, weight: .heavy))
                                .foregroundStyle(game.winner?.id == game.awayTeam?.id ? accentColor : Color(white: 0.5))
                                .frame(minWidth: 30)
                        }
                        
                        // Status badge
                        if game.isFinished {
                            Text("FINAL")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color(white: 0.5))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(Color(white: 0.2))
                                )
                        }
                    }
                    .frame(width: 120)
                    
                    // Away team (right side)
                    if let awayTeam = game.awayTeam {
                        TeamView(
                            team: awayTeam,
                            isWinner: game.winner?.id == awayTeam.id
                        )
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 20)
                .padding(.horizontal, 16)
            }
        }
        .frame(height: 140)
    }
}

struct TeamView: View {
    let team: Team
    let isWinner: Bool
    
    private let accentColor = Color(red: 0.8, green: 1.0, blue: 0.4)
    
    var body: some View {
        VStack(spacing: 10) {
            // Team image
            ZStack {
                // Border ring for winner
                if isWinner {
                    Circle()
                        .stroke(accentColor, lineWidth: 3)
                        .frame(width: 64, height: 64)
                }
                
                // Image
                if let imageURLString = team.fullImageURL, let url = URL(string: imageURLString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 56, height: 56)
                                .clipShape(Circle())
                        case .failure:
                            defaultTeamImage
                        case .empty:
                            ZStack {
                                Circle()
                                    .fill(Color(white: 0.2))
                                    .frame(width: 56, height: 56)
                                ProgressView()
                                    .tint(.white)
                            }
                        @unknown default:
                            defaultTeamImage
                        }
                    }
                } else {
                    defaultTeamImage
                }
            }
            
            // Team name
            Text(team.name.uppercased())
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: 90)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var defaultTeamImage: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [
                        Color(white: 0.25),
                        Color(white: 0.15)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 56, height: 56)
            .overlay {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Color(white: 0.4))
            }
    }
}

#Preview {
    VStack(spacing: 20) {
        GameCardView(
            game: Game(
                id: 1,
                gameTime: Date(),
                stage: true,
                teamStats: [
                    TeamStat(id: 1, score: 10, result: "Lost", teamName: "TAZ", teamLogo: nil),
                    TeamStat(id: 2, score: 13, result: "Won", teamName: "LINCES", teamLogo: nil)
                ]
            )
        )
        
        GameCardView(
            game: Game(
                id: 2,
                gameTime: Date(),
                stage: true,
                teamStats: [
                    TeamStat(id: 3, score: 31, result: "Lost", teamName: "ARAÑAS", teamLogo: nil),
                    TeamStat(id: 1, score: 33, result: "Won", teamName: "TAZ", teamLogo: nil)
                ]
            )
        )
    }
    .padding()
    .background(.black)
}
