//
//  GamesViewModel.swift
//  Brackets
//
//  Created by Humberto on 13/02/26.
//

import Foundation

@MainActor
@Observable
class GamesViewModel {
    var gamesByDate: [(date: String, games: [Game])] = []
    var isLoading = false
    var errorMessage: String?
    
    func loadGames(for tournamentId: Int) async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Fetch the full response with date grouping
            let gamesResponse = try await APIService.shared.fetchGamesResponse(for: tournamentId)
            
            print("🔍 Raw GamesResponse structure:")
            print("   Number of date groups: \(gamesResponse.games.count)")
            for (i, dateGroup) in gamesResponse.games.enumerated() {
                print("   Group \(i): date=\(dateGroup.date), games count=\(dateGroup.games.count)")
                for game in dateGroup.games {
                    print("      Game \(game.id): teamStats=\(game.teamStats?.count ?? -1)")
                }
            }
            
            // Store the grouped games directly from API
            gamesByDate = gamesResponse.games.map { dateGroup in
                (date: dateGroup.date, games: dateGroup.games)
            }
            
            let totalGames = gamesByDate.reduce(0) { $0 + $1.games.count }
            print("✅ Loaded \(totalGames) games in \(gamesByDate.count) date groups")
            
            // Debug: Print each game's team_stats data
            for (index, group) in gamesByDate.enumerated() {
                print("📅 Date Group \(index + 1): \(group.date) (\(group.games.count) games)")
                for game in group.games {
                    print("   📊 Game ID=\(game.id)")
                    if let teamStats = game.teamStats, !teamStats.isEmpty {
                        if teamStats.count >= 2 {
                            print("      🏀 Home: \(teamStats[0].teamName)")
                            print("         - Score: \(teamStats[0].score ?? 0)")
                            print("         - Result: \(teamStats[0].result ?? "N/A")")
                            print("         - Logo: \(teamStats[0].teamLogo ?? "nil")")
                            print("      🏀 Away: \(teamStats[1].teamName)")
                            print("         - Score: \(teamStats[1].score ?? 0)")
                            print("         - Result: \(teamStats[1].result ?? "N/A")")
                            print("         - Logo: \(teamStats[1].teamLogo ?? "nil")")
                        } else {
                            print("      ⚠️ WARNING: Only \(teamStats.count) team(s) in team_stats!")
                        }
                    } else {
                        print("      ❌ ERROR: team_stats is nil or empty for game \(game.id)!")
                    }
                }
            }
        } catch {
            errorMessage = "Failed to load games: \(error.localizedDescription)"
            print("❌ Error loading games: \(error)")
        }
        
        isLoading = false
    }
}
