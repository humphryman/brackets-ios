//
//  Game.swift
//  Brackets
//
//  Created by Humberto on 13/02/26.
//

import Foundation

struct Game: Identifiable, Sendable {
    let id: Int
    let gameTime: Date?
    let stage: String?
    let venue: Venue?
    let teamStats: [TeamStat]?

    // Computed properties for easier access
    var homeTeam: Team? {
        teamStats?.first.map { Team(id: $0.id, name: $0.teamName, image: $0.teamLogo) }
    }
    
    var awayTeam: Team? {
        guard let stats = teamStats, stats.count > 1 else { return nil }
        return Team(id: stats[1].id, name: stats[1].teamName, image: stats[1].teamLogo)
    }
    
    var homeScore: Int? {
        teamStats?.first?.score
    }
    
    var awayScore: Int? {
        guard let stats = teamStats, stats.count > 1 else { return nil }
        return stats[1].score
    }
    
    var playedAt: Date? {
        gameTime
    }
    
    var status: GameStatus {
        // Determine status based on results
        let hasResults = teamStats?.contains { $0.result != nil } ?? false
        if hasResults {
            return .finished
        }
        // If we have a game time in the past, it might be in progress
        if let gameTime = gameTime, gameTime < Date() {
            return .inProgress
        }
        return .scheduled
    }
    
    var isFinished: Bool {
        status == .finished
    }
    
    var winner: Team? {
        guard isFinished else { return nil }
        
        // Find the team with "Won" result
        if let winningTeamStat = teamStats?.first(where: { $0.result == "Won" }) {
            return Team(id: winningTeamStat.id, name: winningTeamStat.teamName, image: winningTeamStat.teamLogo)
        }
        
        // Fallback to score comparison
        guard let homeScore = homeScore,
              let awayScore = awayScore,
              let home = homeTeam,
              let away = awayTeam else {
            return nil
        }
        
        if homeScore > awayScore {
            return home
        } else if awayScore > homeScore {
            return away
        }
        return nil
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case gameTime = "game_time"
        case stage
        case venue
        case teamStats = "team_stats"
    }
}

extension Game: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        gameTime = try container.decodeIfPresent(Date.self, forKey: .gameTime)
        stage = try container.decodeIfPresent(String.self, forKey: .stage)
        teamStats = try container.decodeIfPresent([TeamStat].self, forKey: .teamStats)

        // venue can be a Venue object or a plain string
        if let venueObject = try? container.decodeIfPresent(Venue.self, forKey: .venue) {
            venue = venueObject
        } else if let venueString = try? container.decodeIfPresent(String.self, forKey: .venue) {
            venue = Venue(name: venueString, courtNumber: nil)
        } else {
            venue = nil
        }
    }
}

struct TeamStat: Codable, Sendable {
    let id: Int
    let score: Int?
    let result: String?
    let teamName: String
    let teamLogo: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case score
        case result
        case teamName = "team_name"
        case teamLogo = "team_logo"
    }
}

struct Team: Codable, Equatable, Sendable {
    let id: Int
    let name: String
    let image: String?
    
    var fullImageURL: String? {
        guard let image = image else { return nil }
        
        if image.lowercased().hasPrefix("http://") || image.lowercased().hasPrefix("https://") {
            return image
        }
        
        let imagePath = image.hasPrefix("/") ? String(image.dropFirst()) : image
        return "\(APIConfig.baseURL)/\(imagePath)"
    }
}

enum GameStatus: String, Codable, Sendable {
    case scheduled = "scheduled"
    case inProgress = "in_progress"
    case finished = "finished"
    case cancelled = "cancelled"
}

// Response wrapper - handles the nested date structure
struct GamesResponse: Codable, Sendable {
    let games: [DateGroup]
    
    struct DateGroup: Codable, Sendable {
        let date: String
        let games: [Game]
        
        enum CodingKeys: String, CodingKey {
            case date
            case games
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case games
    }
    
    // Flatten all games from all date groups
    var allGames: [Game] {
        games.flatMap { $0.games }
    }
}
