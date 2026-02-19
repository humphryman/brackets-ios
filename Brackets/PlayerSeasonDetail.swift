//
//  PlayerSeasonDetail.swift
//  Brackets
//

import Foundation

// MARK: - Response

struct PlayerSeasonDetailResponse: Codable {
    let longNameStats: [String: String]
    let shortNameStats: [String: String]
    let playerSeason: PlayerSeasonInfo

    enum CodingKeys: String, CodingKey {
        case longNameStats = "long_name_stats"
        case shortNameStats = "short_name_stats"
        case playerSeason = "player_season"
    }
}

// MARK: - Player Season Info

struct PlayerSeasonInfo: Codable {
    let weight: String?
    let height: String?
    let number: Int?
    let team: String
    let player: Player
    let activeStats: [String]
    let stats: [PlayerSeasonGameStat]
    let playoffsStats: [PlayerSeasonGameStat]

    enum CodingKeys: String, CodingKey {
        case weight, height, number, team, player
        case activeStats = "active_stats"
        case stats
        case playoffsStats = "playoffs_stats"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // weight/height could be string, number, or null
        if let s = try? container.decodeIfPresent(String.self, forKey: .weight) {
            weight = s
        } else if let n = try? container.decodeIfPresent(Double.self, forKey: .weight) {
            weight = String(format: "%.0f", n)
        } else {
            weight = nil
        }

        if let s = try? container.decodeIfPresent(String.self, forKey: .height) {
            height = s
        } else if let n = try? container.decodeIfPresent(Double.self, forKey: .height) {
            height = String(format: "%.0f", n)
        } else {
            height = nil
        }

        number = try container.decodeIfPresent(Int.self, forKey: .number)
        team = try container.decode(String.self, forKey: .team)
        player = try container.decode(Player.self, forKey: .player)
        activeStats = try container.decode([String].self, forKey: .activeStats)
        stats = try container.decode([PlayerSeasonGameStat].self, forKey: .stats)
        playoffsStats = try container.decode([PlayerSeasonGameStat].self, forKey: .playoffsStats)
    }
}

// MARK: - Per-Game Stat

struct PlayerSeasonGameStat: Identifiable, Codable {
    let id: Int
    let opponent: String
    let opponentLogo: String?
    let dynamicStats: [String: Int?]

    enum CodingKeys: String, CodingKey {
        case id, opponent
        case opponentLogo = "opponent_logo"
        case dynamicStats = "dynamic_stats"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        opponent = try container.decode(String.self, forKey: .opponent)
        opponentLogo = try container.decodeIfPresent(String.self, forKey: .opponentLogo)
        dynamicStats = try container.decode([String: Int?].self, forKey: .dynamicStats)
    }

    var opponentFullImageURL: String? {
        guard let logo = opponentLogo else { return nil }
        if logo.lowercased().hasPrefix("http") { return logo }
        let path = logo.hasPrefix("/") ? String(logo.dropFirst()) : logo
        return "\(APIConfig.baseURL)/\(path)"
    }
}
