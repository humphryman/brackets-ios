//
//  Stats.swift
//  Brackets
//
//  Created by Humberto on 16/02/26.
//

import Foundation

// MARK: - Response Wrapper

struct TopStatsResponse: Codable {
    let stats: [StatCategoryData]

    enum CodingKeys: String, CodingKey {
        case stats = "top_stats"
    }
}

// MARK: - Models

struct StatCategoryData: Codable, Identifiable {
    var id: String { category }
    let category: String
    let displayName: String
    let unit: String
    let leaders: [PlayerStat]

    enum CodingKeys: String, CodingKey {
        case category
        case displayName = "display_name"
        case unit
        case leaders
    }
}

struct PlayerStat: Identifiable, Codable {
    let id: Int
    let playerName: String
    let teamName: String
    let value: Double
    let teamLogo: String?

    enum CodingKeys: String, CodingKey {
        case id = "player_id"
        case playerName = "player_name"
        case teamName = "team_name"
        case value
        case teamLogo = "team_logo"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        playerName = try container.decode(String.self, forKey: .playerName)
        teamName = try container.decode(String.self, forKey: .teamName)
        teamLogo = try container.decodeIfPresent(String.self, forKey: .teamLogo)

        // Handle value as either Double or String from the API
        if let doubleValue = try? container.decode(Double.self, forKey: .value) {
            value = doubleValue
        } else if let stringValue = try? container.decode(String.self, forKey: .value),
                  let parsed = Double(stringValue) {
            value = parsed
        } else {
            throw DecodingError.keyNotFound(
                CodingKeys.value,
                DecodingError.Context(codingPath: container.codingPath, debugDescription: "Could not decode 'value' as Double or String")
            )
        }
    }
}
