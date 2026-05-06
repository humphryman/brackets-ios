//
//  Stats.swift
//  Brackets
//
//  Created by Humberto on 16/02/26.
//

import Foundation

// MARK: - Response Wrapper

struct TopStatsResponse: Codable, Sendable {
    let topStats: [StatCategory]

    enum CodingKeys: String, CodingKey {
        case topStats = "top_stats"
    }
}

// MARK: - Models

struct StatCategory: Codable, Identifiable, Sendable {
    var id: String { name ?? "unknown" }
    let name: String?
    let stats: [PlayerStatEntry]
}

struct PlayerStatEntry: Codable, Identifiable, Sendable {
    var id: Int { playerSeasonId }
    let statShortName: String
    let statName: String
    let score: Double
    let teamName: String
    let playerSeasonId: Int
    let player: Player

    enum CodingKeys: String, CodingKey {
        case statShortName = "stat_short_name"
        case statName = "stat_name"
        case score
        case teamName = "team_name"
        case playerSeasonId = "player_season_id"
        case player
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        statShortName = try container.decode(String.self, forKey: .statShortName)
        statName = try container.decode(String.self, forKey: .statName)
        teamName = try container.decode(String.self, forKey: .teamName)
        playerSeasonId = try container.decode(Int.self, forKey: .playerSeasonId)
        player = try container.decode(Player.self, forKey: .player)

        if let doubleValue = try? container.decode(Double.self, forKey: .score) {
            score = doubleValue
        } else if let stringValue = try? container.decode(String.self, forKey: .score),
                  let parsed = Double(stringValue) {
            score = parsed
        } else {
            score = 0
        }
    }
}

struct Player: Codable, Identifiable, Sendable {
    let id: Int
    let firstName: String
    let lastName: String
    let dob: String?
    let position: String?
    let gender: String?
    let nickname: String?
    let picture: String?

    enum CodingKeys: String, CodingKey {
        case id
        case firstName = "first_name"
        case lastName = "last_name"
        case dob
        case position
        case gender
        case nickname
        case picture
    }

    var fullName: String {
        "\(firstName) \(lastName)"
    }
}
