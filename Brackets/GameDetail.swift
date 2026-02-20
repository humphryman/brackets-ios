//
//  GameDetail.swift
//  Brackets
//
//  Created by Humberto on 16/02/26.
//

import Foundation

// MARK: - Top-level response

struct GameDetailResponse: Codable {
    let longNameStats: [String: String]
    let shortNameStats: [String: String]
    let game: GameDetail

    enum CodingKeys: String, CodingKey {
        case longNameStats = "long_name_stats"
        case shortNameStats = "short_name_stats"
        case game
    }
}

// MARK: - Game detail

struct GameDetail: Identifiable, Codable {
    let id: Int
    let played: Bool
    let phase: String?
    let round: String?
    let gameTime: Date?
    let stage: Bool
    let venue: Venue?
    let activeStats: [String]
    let gameSets: GameSets
    let teamStats: [GameDetailTeamStat]

    enum CodingKeys: String, CodingKey {
        case id, played, phase, round, stage, venue
        case gameTime = "game_time"
        case activeStats = "active_stats"
        case gameSets = "game_sets"
        case teamStats = "team_stats"
    }
}

// MARK: - Venue

struct Venue: Codable {
    let name: String
    let courtNumber: String?

    enum CodingKeys: String, CodingKey {
        case name
        case courtNumber = "court_number"
    }
}

// MARK: - Game Sets (teams + scores)

struct GameSets: Codable {
    let teamAId: Int
    let teamA: String
    let teamALogo: String?
    let teamAScore: Int
    let teamAScores: [Int]?
    let teamBId: Int
    let teamB: String
    let teamBLogo: String?
    let teamBScore: Int
    let teamBScores: [Int]?

    enum CodingKeys: String, CodingKey {
        case teamAId = "team_a_id"
        case teamA = "team_a"
        case teamALogo = "team_a_logo"
        case teamAScore = "team_a_score"
        case teamAScores = "team_a_scores"
        case teamBId = "team_b_id"
        case teamB = "team_b"
        case teamBLogo = "team_b_logo"
        case teamBScore = "team_b_score"
        case teamBScores = "team_b_scores"
    }

    var teamAFullImageURL: String? {
        guard let logo = teamALogo else { return nil }
        if logo.lowercased().hasPrefix("http") { return logo }
        let path = logo.hasPrefix("/") ? String(logo.dropFirst()) : logo
        return "\(APIConfig.baseURL)/\(path)"
    }

    var teamBFullImageURL: String? {
        guard let logo = teamBLogo else { return nil }
        if logo.lowercased().hasPrefix("http") { return logo }
        let path = logo.hasPrefix("/") ? String(logo.dropFirst()) : logo
        return "\(APIConfig.baseURL)/\(path)"
    }
}

// MARK: - Team stat (per team, contains player list)

struct GameDetailTeamStat: Identifiable, Codable {
    let id: Int
    let teamName: String
    let score: Int
    let result: String?
    let teamLogo: String?
    let lastFiveGames: [Int?]?
    let playerStats: [PlayerGameStat]

    enum CodingKeys: String, CodingKey {
        case id
        case teamName = "team_name"
        case score
        case result
        case teamLogo = "team_logo"
        case lastFiveGames = "last_five_games"
        case playerStats = "player_stats"
    }

    var fullImageURL: String? {
        guard let logo = teamLogo else { return nil }
        if logo.lowercased().hasPrefix("http") { return logo }
        let path = logo.hasPrefix("/") ? String(logo.dropFirst()) : logo
        return "\(APIConfig.baseURL)/\(path)"
    }
}

// MARK: - Player stat

struct PlayerGameStat: Identifiable, Codable {
    let id: Int
    let playerName: String
    let playerShortName: String
    let playerFirstName: String
    let playerLastName: String
    let playerId: Int?
    let playerNumber: Int?
    let playerGender: String?
    let playerImage: String?
    let dynamicStats: [String: Int?]

    /// True when this entry represents the team totals row ("Equipo")
    var isTeamEntry: Bool {
        playerFirstName == "Equipo"
    }

    var fullImageURL: String? {
        guard let img = playerImage else { return nil }
        if img.lowercased().hasPrefix("http") { return img }
        let path = img.hasPrefix("/") ? String(img.dropFirst()) : img
        return "\(APIConfig.baseURL)/\(path)"
    }

    enum CodingKeys: String, CodingKey {
        case id
        case playerName = "player_name"
        case playerShortName = "player_short_name"
        case playerFirstName = "player_first_name"
        case playerLastName = "player_last_name"
        case playerId = "player_id"
        case playerNumber = "player_number"
        case playerGender = "player_gender"
        case playerImage = "player_image"
        case dynamicStats = "dynamic_stats"
    }

    // Custom decoder for dynamic_stats where values can be Int or null
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        playerName = try container.decode(String.self, forKey: .playerName)
        playerShortName = try container.decode(String.self, forKey: .playerShortName)
        playerFirstName = try container.decode(String.self, forKey: .playerFirstName)
        playerLastName = try container.decode(String.self, forKey: .playerLastName)
        playerId = try container.decodeIfPresent(Int.self, forKey: .playerId)
        playerNumber = try container.decodeIfPresent(Int.self, forKey: .playerNumber)
        playerGender = try container.decodeIfPresent(String.self, forKey: .playerGender)
        playerImage = try container.decodeIfPresent(String.self, forKey: .playerImage)

        // Decode dynamic_stats: { "points": null, "tr": 0, ... }
        let statsContainer = try container.decode([String: Int?].self, forKey: .dynamicStats)
        dynamicStats = statsContainer
    }
}
