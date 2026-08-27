//
//  PlayerStatsShareModel.swift
//  Brackets
//
//  Render-ready model for the athlete share card. The design itself lives in
//  `PlayerPortraitShareCard.swift`.
//

import SwiftUI
import UIKit

// MARK: - Model

/// Flat, render-ready description of one player's game. The card view never touches
/// `GameDetailResponse`, and every remote image is already a `UIImage` — `ImageRenderer`
/// snapshots synchronously and would export an unresolved `AsyncImage` as a blank.
struct PlayerStatsShareModel {
    struct StatCell: Identifiable {
        let id: String
        let value: String
        let label: String
    }

    var firstName: String = ""
    var lastName: String = ""
    var teamName: String = ""
    var photo: UIImage?

    /// In the same order the results table and the stats sheet use.
    var stats: [StatCell] = []

    var teamAName: String = "TBD"
    var teamBName: String = "TBD"
    var teamALogo: UIImage?
    var teamBLogo: UIImage?
    var teamAScore: Int?
    var teamBScore: Int?

    /// Footer context, matching the game cards.
    var tournamentName: String?
    var date: Date?
    var venueName: String?

    /// Leading stat — points in every tournament seen so far, since `active_stats`
    /// puts it first. Design C sets this one huge.
    var heroStat: StatCell? { stats.first }

    var supportingStats: [StatCell] { Array(stats.dropFirst()) }

    var initials: String {
        String(firstName.prefix(1) + lastName.prefix(1)).uppercased()
    }

    var teamAWon: Bool {
        guard let a = teamAScore, let b = teamBScore else { return false }
        return a > b
    }

    var teamBWon: Bool {
        guard let a = teamAScore, let b = teamBScore else { return false }
        return b > a
    }

    /// Builds the model from a loaded game detail, downloading the player photo and both
    /// team logos before returning.
    ///
    /// Team name/logo/score resolution mirrors `ShareCardModel.make` — the
    /// `gameSets` → `teamStats` fallback documented in CLAUDE.md.
    static func make(
        player: PlayerGameStat,
        teamName: String,
        detail: GameDetailResponse,
        tournamentName: String? = nil
    ) async -> PlayerStatsShareModel {
        let game = detail.game
        let sets = game.gameSets
        let teams = game.teamStats ?? []
        let teamA = teams.count > 0 ? teams[0] : nil
        let teamB = teams.count > 1 ? teams[1] : nil

        var model = PlayerStatsShareModel()
        model.firstName = player.playerFirstName.trimmingCharacters(in: .whitespaces)
        model.lastName = player.playerLastName.trimmingCharacters(in: .whitespaces)
        model.teamName = teamName.trimmingCharacters(in: .whitespaces)

        model.stats = (game.activeStats ?? []).map { key in
            let value = player.dynamicStats[key] ?? nil
            return StatCell(
                id: key,
                value: value.map { "\($0)" } ?? "-",
                label: detail.longNameStats[key] ?? detail.shortNameStats[key] ?? key.uppercased()
            )
        }

        model.teamAName = sets?.teamA ?? teamA?.teamName ?? "TBD"
        model.teamBName = sets?.teamB ?? teamB?.teamName ?? "TBD"

        model.tournamentName = tournamentName
        model.date = game.gameTime
        model.venueName = game.venue.map { venue in
            venue.name + (venue.courtNumber.map { " · \($0)" } ?? "")
        }

        // Scores stay `nil` for unplayed games so the card shows "VS" instead of "0 - 0".
        if game.isFinished || game.played == true {
            model.teamAScore = teamA?.score ?? sets?.teamAScore ?? 0
            model.teamBScore = teamB?.score ?? sets?.teamBScore ?? 0
        }

        let images = await ShareImageLoader.shared.load([
            player.fullImageURL,
            sets?.teamAFullImageURL ?? teamA?.fullImageURL,
            sets?.teamBFullImageURL ?? teamB?.fullImageURL
        ])
        model.photo = images[0]
        model.teamALogo = images[1]
        model.teamBLogo = images[2]

        return model
    }
}
