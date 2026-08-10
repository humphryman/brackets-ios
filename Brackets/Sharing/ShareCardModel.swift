//
//  ShareCardModel.swift
//  Brackets
//

import SwiftUI
import UIKit

// MARK: - Style

/// The available share card designs. Adding a design means adding a case here
/// and a branch in `ShareCardStyle.view(for:)`.
enum ShareCardStyle: String, CaseIterable, Identifiable {
    case scoreboard
    case spotlight

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .scoreboard: return "Marcador"
        case .spotlight:  return "Destacado"
        }
    }
}

// MARK: - Sides

enum ShareCardSide {
    case a, b, tie
}

// MARK: - Model

/// Flat, render-ready description of a game.
///
/// This is the only contract between game data and the card designs: the card views
/// never touch `GameDetailResponse`. Critically, every remote image is already
/// resolved to a `UIImage` — `ImageRenderer` snapshots synchronously and will export
/// an unresolved `AsyncImage` as a blank placeholder.
struct ShareCardModel {
    var tournamentName: String?
    var stage: String?
    var date: Date?
    var venueName: String?

    /// Drives the oversized vertical label down the right edge. Not every entry point
    /// has the `Tournament` to hand, so this is optional by design.
    var gender: Gender?

    var teamAName: String = "TBD"
    var teamBName: String = "TBD"
    var teamALogo: UIImage?
    var teamBLogo: UIImage?

    /// `nil` on both sides means the game has not been played yet.
    var teamAScore: Int?
    var teamBScore: Int?

    /// Raw period breakdown, passed straight to the existing `QuarterScoresTable`
    /// rather than re-deriving its column logic here.
    var teamAPeriodScores: [String: QuarterScoreValue]?
    var teamBPeriodScores: [String: QuarterScoreValue]?
    var periodColumns: [PeriodColumn]?
    var hasPeriodScores: Bool = false

    var isUpcoming: Bool {
        teamAScore == nil && teamBScore == nil
    }

    /// Right-edge vertical label: gender when we have it, otherwise the stage, which is
    /// always present on a game and reads just as well set large.
    var edgeLabel: String? {
        if let gender { return gender.displayName }
        guard let stage, !stage.isEmpty else { return nil }
        return stage
    }

    /// "Resumen del partido" / "Próximo partido" — the small rotated left-edge label.
    var kickerLabel: String {
        isUpcoming ? "Próximo partido" : "Resumen del partido"
    }

    var winner: ShareCardSide? {
        guard let a = teamAScore, let b = teamBScore else { return nil }
        if a > b { return .a }
        if b > a { return .b }
        return .tie
    }

    func isWinner(_ side: ShareCardSide) -> Bool {
        guard let winner, winner != .tie else { return false }
        return winner == side
    }
}

// MARK: - Building from API data

extension ShareCardModel {

    /// Builds a card model from a loaded game detail, downloading the team logos and
    /// the player-of-the-game photo before returning.
    ///
    /// Team name/logo/score resolution mirrors `GameResultView.scoreCard` — the
    /// `gameSets` → `teamStats` fallback documented in CLAUDE.md.
    static func make(
        detail: GameDetailResponse,
        tournamentName: String?,
        gender: Gender? = nil
    ) async -> ShareCardModel {
        let game = detail.game
        let sets = game.gameSets
        let teams = game.teamStats ?? []
        let teamA = teams.count > 0 ? teams[0] : nil
        let teamB = teams.count > 1 ? teams[1] : nil

        var model = ShareCardModel()
        model.tournamentName = tournamentName
        model.stage = game.stage
        model.gender = gender
        model.date = game.gameTime
        model.venueName = game.venue.map { venue in
            venue.name + (venue.courtNumber.map { " · \($0)" } ?? "")
        }

        model.teamAName = sets?.teamA ?? teamA?.teamName ?? "TBD"
        model.teamBName = sets?.teamB ?? teamB?.teamName ?? "TBD"

        // Scores stay `nil` for unplayed games so the card can show "VS" instead of "0 - 0".
        if game.isFinished || game.played == true {
            model.teamAScore = teamA?.score ?? sets?.teamAScore ?? 0
            model.teamBScore = teamB?.score ?? sets?.teamBScore ?? 0
        }

        model.teamAPeriodScores = teamA?.quarterScores
        model.teamBPeriodScores = teamB?.quarterScores
        model.periodColumns = game.periodColumns
        model.hasPeriodScores = (teamA?.hasQuarterScores ?? false) || (teamB?.hasQuarterScores ?? false)

        // One concurrent fetch for every remote image the cards can use. The player-of-
        // the-game photo is deliberately not fetched: no card uses an athlete portrait.
        let images = await ShareImageLoader.shared.load([
            sets?.teamAFullImageURL ?? teamA?.fullImageURL,
            sets?.teamBFullImageURL ?? teamB?.fullImageURL
        ])
        model.teamALogo = images[0]
        model.teamBLogo = images[1]

        return model
    }
}

// MARK: - Formatting

/// Date formatters for the share cards. Every one uses `es_MX` and the API timezone,
/// per CLAUDE.md — never `ISO8601DateFormatter`.
enum ShareCardFormat {

    private static func formatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_MX")
        formatter.timeZone = AppConfig.DateTime.apiTimeZone
        formatter.dateFormat = format
        return formatter
    }

    private static let longDateFormatter = formatter("d 'de' MMMM, yyyy")
    private static let weekdayFormatter = formatter("EEEE d 'de' MMMM")
    private static let compactFormatter = formatter("EEE d MMM")
    private static let timeFormatter = formatter("HH:mm")

    /// e.g. "9 de agosto, 2026"
    static func date(_ date: Date) -> String {
        longDateFormatter.string(from: date)
    }

    /// e.g. "Domingo 9 de agosto".
    /// Only the leading character is uppercased — `.capitalized` would also hit the
    /// preposition and produce "Domingo 9 De Agosto".
    static func weekday(_ date: Date) -> String {
        let text = weekdayFormatter.string(from: date)
        guard let first = text.first else { return text }
        return first.uppercased() + text.dropFirst()
    }

    /// e.g. "dom 9 ago" — short enough to sit inside the cards' rule label, which the
    /// full weekday string overflows.
    static func compact(_ date: Date) -> String {
        compactFormatter.string(from: date).replacingOccurrences(of: ".", with: "")
    }

    /// e.g. "19:30"
    static func time(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }

    /// Two-or-three letter initials, matching `GameResultView.getInitials`.
    static func initials(_ name: String) -> String {
        let words = name.split(separator: " ")
        if words.count >= 2 {
            return String(words[0].prefix(1) + words[1].prefix(1)).uppercased()
        } else if let first = words.first {
            return String(first.prefix(3)).uppercased()
        }
        return "?"
    }
}
