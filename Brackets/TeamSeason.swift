//
//  TeamSeason.swift
//  Brackets
//

import Foundation

struct TeamSeasonResponse: Decodable, Sendable {
    let teamSeason: TeamSeasonDetail

    enum CodingKeys: String, CodingKey {
        case teamSeason = "team_season"
    }
}

struct TeamSeasonDetail: Decodable, Sendable {
    let games: [Game]
    let playerSeasons: [PlayerSeason]
    let upcomingGames: [Game]
    let statLeaders: [StatLeaderCategory]

    enum CodingKeys: String, CodingKey {
        case games
        case playerSeasons = "player_seasons"
        case upcomingGames = "upcoming_games"
        case statLeaders = "stat_leaders"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        games = try container.decodeIfPresent([Game].self, forKey: .games) ?? []
        playerSeasons = try container.decodeIfPresent([PlayerSeason].self, forKey: .playerSeasons) ?? []
        statLeaders = try container.decodeIfPresent([StatLeaderCategory].self, forKey: .statLeaders) ?? []

        // upcoming_games can be an array or a single object (upcoming_game)
        if let arr = try? container.decodeIfPresent([Game].self, forKey: .upcomingGames) {
            upcomingGames = arr
        } else {
            upcomingGames = []
        }
    }

    /// All games combined (played + upcoming), newest date on top
    var allGames: [Game] {
        let combined = games + upcomingGames
        return combined.sorted { ($0.gameTime ?? .distantPast) > ($1.gameTime ?? .distantPast) }
    }

    var nonEmptyStatLeaders: [StatLeaderCategory] {
        statLeaders.filter { $0.longName != nil && !$0.players.isEmpty }
    }
}

struct StatLeaderCategory: Codable, Identifiable, Sendable {
    let longName: String?
    let shortName: String
    let players: [StatLeaderEntry]

    var id: String { shortName }

    enum CodingKeys: String, CodingKey {
        case longName = "long_name"
        case shortName = "short_name"
        case players
    }
}

struct StatLeaderEntry: Codable, Identifiable, Sendable {
    let playerSeasonId: Int
    let firstName: String
    let lastName: String
    let picture: String?
    let total: Int

    var id: Int { playerSeasonId }

    var fullImageURL: String? {
        guard let picture = picture else { return nil }

        if picture.lowercased().hasPrefix("http://") || picture.lowercased().hasPrefix("https://") {
            return picture
        }

        let imagePath = picture.hasPrefix("/") ? String(picture.dropFirst()) : picture
        return "\(APIConfig.baseURL)/\(imagePath)"
    }

    enum CodingKeys: String, CodingKey {
        case playerSeasonId = "player_season_id"
        case firstName = "first_name"
        case lastName = "last_name"
        case picture
        case total
    }
}

struct PlayerSeason: Identifiable, Codable, Sendable {
    let id: Int
    let number: Int?
    let player: Player

    var firstName: String { player.firstName }
    var lastName: String { player.lastName }

    var fullImageURL: String? {
        guard let picture = player.picture else { return nil }

        if picture.lowercased().hasPrefix("http://") || picture.lowercased().hasPrefix("https://") {
            return picture
        }

        let imagePath = picture.hasPrefix("/") ? String(picture.dropFirst()) : picture
        return "\(APIConfig.baseURL)/\(imagePath)"
    }

    struct Player: Codable, Sendable {
        let id: Int
        let firstName: String
        let lastName: String
        let gender: String?
        let picture: String?

        enum CodingKeys: String, CodingKey {
            case id
            case firstName = "first_name"
            case lastName = "last_name"
            case gender
            case picture
        }
    }
}
