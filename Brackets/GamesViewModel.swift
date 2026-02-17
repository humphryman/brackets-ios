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
    
    // Date formatter for parsing the API date strings
    private let inputDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd" // Adjust this to match your API format
        formatter.locale = Locale(identifier: "es_MX")
        return formatter
    }()
    
    // Date formatter for display
    private let displayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM yyyy" // Day Month Year (e.g., "14 Febrero 2026")
        formatter.locale = Locale(identifier: "es_MX")
        return formatter
    }()
    
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
            
            // Store the grouped games with formatted dates
            gamesByDate = gamesResponse.games.map { dateGroup in
                let formattedDate = formatDate(dateGroup.date)
                return (date: formattedDate, games: dateGroup.games)
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
    
    // Helper function to format dates from API format to display format
    private func formatDate(_ dateString: String) -> String {
        // Try to parse the date string
        if let date = inputDateFormatter.date(from: dateString) {
            return displayDateFormatter.string(from: date)
        }
        // If parsing fails, return the original string
        return dateString
    }
}
