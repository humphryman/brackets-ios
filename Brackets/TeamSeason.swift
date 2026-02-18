//
//  TeamSeason.swift
//  Brackets
//

import Foundation

struct TeamSeasonResponse: Codable {
    let teamSeason: TeamSeasonDetail

    enum CodingKeys: String, CodingKey {
        case teamSeason = "team_season"
    }
}

struct TeamSeasonDetail: Codable {
    let games: [Game]
    let playerSeasons: [PlayerSeason]
    let upcomingGame: Game?

    enum CodingKeys: String, CodingKey {
        case games
        case playerSeasons = "player_seasons"
        case upcomingGame = "upcoming_game"
    }
}

struct PlayerSeason: Identifiable, Codable {
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

    struct Player: Codable {
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
