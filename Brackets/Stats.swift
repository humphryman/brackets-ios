//
//  Stats.swift
//  Brackets
//
//  Created by Humberto on 16/02/26.
//

import Foundation

// MARK: - Response Wrapper

struct TopStatsResponse: Codable {
    let topStats: [StatCategory]

    enum CodingKeys: String, CodingKey {
        case topStats = "top_stats"
    }
}

// MARK: - Models

struct StatCategory: Codable, Identifiable {
    var id: String { name }
    let name: String
    let stats: [PlayerStatEntry]
}

struct PlayerStatEntry: Codable, Identifiable {
    var id: Int { playerSeasonId }
    let statShortName: String
    let statName: String
    let score: Int
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
}

struct Player: Codable, Identifiable {
    let id: Int
    let firstName: String
    let lastName: String
    let dob: String?
    let position: String?
    let gender: String
    let nickname: String
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
