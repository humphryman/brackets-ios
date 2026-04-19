//
//  GameDetail.swift
//  Brackets
//
//  Created by Humberto on 16/02/26.
//

import Foundation

// MARK: - Top-level response

struct GameDetailResponse: Codable, Sendable {
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

struct GameDetail: Identifiable, Sendable {
    let id: Int
    let played: Bool?
    let phase: String?
    let round: String?
    let gameTime: Date?
    let stage: String?
    let venue: Venue?
    let activeStats: [String]?
    let gameSets: GameSets?
    let teamStats: [GameDetailTeamStat]?

    enum CodingKeys: String, CodingKey {
        case id, played, phase, round, stage, venue
        case gameTime = "game_time"
        case activeStats = "active_stats"
        case gameSets = "game_sets"
        case teamStats = "team_stats"
    }
}

extension GameDetail: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        played = try container.decodeIfPresent(Bool.self, forKey: .played)
        phase = try container.decodeIfPresent(String.self, forKey: .phase)
        round = try container.decodeIfPresent(String.self, forKey: .round)
        gameTime = try container.decodeIfPresent(Date.self, forKey: .gameTime)
        stage = try container.decodeIfPresent(String.self, forKey: .stage)
        venue = try container.decodeIfPresent(Venue.self, forKey: .venue)
        activeStats = try container.decodeIfPresent([String].self, forKey: .activeStats)
        teamStats = try container.decodeIfPresent([GameDetailTeamStat].self, forKey: .teamStats)

        // game_sets can be a GameSets object or an empty array []
        if let sets = try? container.decodeIfPresent(GameSets.self, forKey: .gameSets) {
            gameSets = sets
        } else {
            gameSets = nil
        }
    }
}

// MARK: - Venue

struct Venue: Sendable {
    let name: String
    let courtNumber: String?
    let lat: Double?
    let lng: Double?

    enum CodingKeys: String, CodingKey {
        case name
        case courtNumber = "court_number"
        case court
        case lat
        case lng
    }

    init(name: String, courtNumber: String?, lat: Double?, lng: Double?) {
        self.name = name
        self.courtNumber = courtNumber
        self.lat = lat
        self.lng = lng
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        // court can come as "court_number" or "court"
        if let val = try? container.decodeIfPresent(String.self, forKey: .courtNumber) {
            courtNumber = val
        } else if let val = try? container.decodeIfPresent(String.self, forKey: .court) {
            courtNumber = val
        } else if let val = try? container.decodeIfPresent(Int.self, forKey: .court) {
            courtNumber = String(val)
        } else if let val = try? container.decodeIfPresent(Int.self, forKey: .courtNumber) {
            courtNumber = String(val)
        } else {
            courtNumber = nil
        }

        // lat/lng can come as Double or String from the API
        if let val = try? container.decodeIfPresent(Double.self, forKey: .lat) {
            lat = val
        } else if let str = try? container.decodeIfPresent(String.self, forKey: .lat) {
            lat = Double(str)
        } else {
            lat = nil
        }

        if let val = try? container.decodeIfPresent(Double.self, forKey: .lng) {
            lng = val
        } else if let str = try? container.decodeIfPresent(String.self, forKey: .lng) {
            lng = Double(str)
        } else {
            lng = nil
        }
    }

    var hasCoordinates: Bool {
        lat != nil && lng != nil
    }

    var mapsURL: URL? {
        guard let lat = lat, let lng = lng else { return nil }
        let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "maps://?q=\(encodedName)&ll=\(lat),\(lng)")
    }

    var googleMapsURL: URL? {
        guard let lat = lat, let lng = lng else { return nil }
        let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "https://www.google.com/maps/search/?api=1&query=\(lat),\(lng)&query_place_id=\(encodedName)")
    }
}

extension Venue: Codable {
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(courtNumber, forKey: .courtNumber)
        try container.encodeIfPresent(lat, forKey: .lat)
        try container.encodeIfPresent(lng, forKey: .lng)
    }
}

// MARK: - Game Sets (teams + scores)

struct GameSets: Codable, Sendable {
    let teamAId: Int
    let teamA: String
    let teamALogo: String?
    let teamAScore: Int?
    let teamAScores: [Int]?
    let teamBId: Int
    let teamB: String
    let teamBLogo: String?
    let teamBScore: Int?
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

struct GameDetailTeamStat: Identifiable, Codable, Sendable {
    let id: Int
    let teamName: String
    let score: Int?
    let result: String?
    let teamLogo: String?
    let lastFiveGames: [Int?]?
    let totalTeamStats: [String: Double]?
    let playerStats: [PlayerGameStat]?
    let gamesPlayed: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case teamName = "team_name"
        case score
        case result
        case teamLogo = "team_logo"
        case lastFiveGames = "last_five_games"
        case totalTeamStats = "total_team_stats"
        case playerStats = "player_stats"
        case gamesPlayed = "games_played"
    }

    /// Average stats per game
    var averageTeamStats: [String: Double]? {
        guard let totals = totalTeamStats, let gp = effectiveGamesPlayed, gp > 0 else { return totalTeamStats }
        return totals.mapValues { $0 / Double(gp) }
    }

    /// Games played from API or derived from last five games
    var effectiveGamesPlayed: Int? {
        if let gp = gamesPlayed { return gp }
        // Fallback: count non-nil entries in lastFiveGames as minimum
        return lastFiveGames?.compactMap({ $0 }).count
    }

    var fullImageURL: String? {
        guard let logo = teamLogo else { return nil }
        if logo.lowercased().hasPrefix("http") { return logo }
        let path = logo.hasPrefix("/") ? String(logo.dropFirst()) : logo
        return "\(APIConfig.baseURL)/\(path)"
    }
}

// MARK: - Player stat

struct PlayerGameStat: Identifiable, Codable, Sendable {
    let id: Int
    let playerName: String
    let playerShortName: String
    let playerFirstName: String
    let playerLastName: String
    let playerId: Int?
    let playerSeasonId: Int?
    let playerNumber: Int?
    let playerGender: String?
    let playerImage: String?
    let played: Bool
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
        case playerSeasonId = "player_season_id"
        case playerNumber = "player_number"
        case playerGender = "player_gender"
        case playerImage = "player_image"
        case played
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
        playerSeasonId = try container.decodeIfPresent(Int.self, forKey: .playerSeasonId)
        playerNumber = try container.decodeIfPresent(Int.self, forKey: .playerNumber)
        playerGender = try container.decodeIfPresent(String.self, forKey: .playerGender)
        playerImage = try container.decodeIfPresent(String.self, forKey: .playerImage)
        played = try container.decodeIfPresent(Bool.self, forKey: .played) ?? true

        // Decode dynamic_stats: { "points": null, "tr": 0, ... }
        let statsContainer = try container.decode([String: Int?].self, forKey: .dynamicStats)
        dynamicStats = statsContainer
    }
}

// MARK: - Venue Label (reusable, tappable when coordinates available)

import SwiftUI

struct VenueLabel: View {
    let venue: Venue
    @Environment(\.openURL) private var openURL

    private var venueText: String {
        venue.name + (venue.courtNumber.map { " - \($0)" } ?? "")
    }

    var body: some View {
        if let mapsURL = venue.googleMapsURL {
            Button {
                openURL(mapsURL)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.Colors.accent)
                    Text(venueText)
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.Colors.accent)
                        .underline()
                }
            }
            .buttonStyle(.plain)
        } else {
            Text(venueText)
                .font(.system(size: 13))
                .foregroundStyle(Color(white: 0.5))
        }
    }
}
