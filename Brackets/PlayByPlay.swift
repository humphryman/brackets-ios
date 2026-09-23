//
//  PlayByPlay.swift
//  Brackets
//
//  Pure transform that turns the raw play-by-play feed into period-grouped display
//  rows. Kept free of SwiftUI so it can be unit-tested (see PlayByPlayTests).
//

import Foundation

/// Which scoreboard column a team drives.
enum PlayByPlaySide: Equatable { case a, b }

/// Drives the row's action color. `scoring` and `neutral` read gray; `entra` is the
/// lime accent; `salePerdida` is red.
enum PlayByPlayActionKind: Equatable { case scoring, entra, salePerdida, neutral }

/// Which side's running score to emphasize on a scoring row, oriented to the header's
/// team order (`left` = teams[0]). `none` hides the score entirely.
enum PlayByPlayEmphasis: Equatable { case left, right, none }

/// Minimal team input for side inference (id + final score).
struct PlayByPlayTeam {
    let id: Int
    let score: Int?
}

/// A single rendered play-by-play row.
struct PlayByPlayRow: Identifiable {
    let id: Int
    let playerNumber: Int?
    let playerFirstName: String
    let playerLastName: String
    let teamName: String
    let teamLogo: String?
    let actionLabel: String
    let actionKind: PlayByPlayActionKind
    /// Running scores oriented to the header's team order (left = teams[0]).
    let leftScore: Int
    let rightScore: Int
    let emphasis: PlayByPlayEmphasis

    var showsScore: Bool { emphasis != .none }

    var fullTeamLogoURL: String? {
        guard let logo = teamLogo else { return nil }
        if logo.lowercased().hasPrefix("http") { return logo }
        let path = logo.hasPrefix("/") ? String(logo.dropFirst()) : logo
        return "\(APIConfig.baseURL)/\(path)"
    }
}

/// One period section (e.g. "PERIODO 2") with its rows, newest-first.
struct PlayByPlayPeriod: Identifiable {
    let id: String
    let title: String
    let rows: [PlayByPlayRow]
}

enum PlayByPlayBuilder {
    private static let scoringStats: Set<String> = ["two_pm", "three_pm", "ftm"]

    /// Spanish label + color kind for a stat_name. Unknown names fall back to the
    /// server's long-name dictionary, then the raw key.
    static func action(
        for statName: String,
        foulCount: Int?,
        longNameStats: [String: String]
    ) -> (label: String, kind: PlayByPlayActionKind) {
        switch statName {
        case "two_pm": return ("2 puntos", .scoring)
        case "three_pm": return ("3 puntos", .scoring)
        case "ftm": return ("Tiro libre", .scoring)
        case "pfs":
            if let n = foulCount { return ("Falta personal (\(n))", .neutral) }
            return ("Falta personal", .neutral)
        case "to": return ("Pérdida", .salePerdida)
        case "sale": return ("Sale", .salePerdida)
        case "entra": return ("Entra", .entra)
        default: return (longNameStats[statName] ?? statName, .neutral)
        }
    }

    /// "2P" -> "PERIODO 2". Unknown formats are uppercased as-is.
    static func periodTitle(_ raw: String) -> String {
        let up = raw.uppercased()
        if up.hasSuffix("P"), let n = Int(up.dropLast()) { return "PERIODO \(n)" }
        return up
    }

    /// Maps each team_stat_id to the scoreboard side it drives. score_a/score_b are
    /// NOT in team_stats order, so infer each team's side from which total its baskets
    /// increment; fall back to matching final scores, then to filling the free side.
    static func sideByTeam(events: [PlayByPlayEvent], teams: [PlayByPlayTeam]) -> [Int: PlayByPlaySide] {
        var map: [Int: PlayByPlaySide] = [:]
        var prevA = 0, prevB = 0
        for e in events.reversed() {
            if scoringStats.contains(e.statName) {
                if e.scoreA > prevA, map[e.teamStatId] == nil { map[e.teamStatId] = .a }
                if e.scoreB > prevB, map[e.teamStatId] == nil { map[e.teamStatId] = .b }
            }
            prevA = e.scoreA; prevB = e.scoreB
        }
        // events.first is the newest row, so its scores are the final totals.
        let finalA = events.first?.scoreA ?? 0
        let finalB = events.first?.scoreB ?? 0
        for t in teams where map[t.id] == nil {
            if let s = t.score {
                if s == finalA, !map.values.contains(.a) { map[t.id] = .a }
                else if s == finalB, !map.values.contains(.b) { map[t.id] = .b }
            }
        }
        for t in teams where map[t.id] == nil {
            if !map.values.contains(.a) { map[t.id] = .a }
            else if !map.values.contains(.b) { map[t.id] = .b }
        }
        return map
    }

    /// Running personal-foul count per player, keyed to each foul event's id.
    static func foulCounts(events: [PlayByPlayEvent]) -> [Int: Int] {
        var counts: [Int: Int] = [:]
        var tally: [String: Int] = [:]
        for e in events.reversed() where e.statName == "pfs" {
            let key = "\(e.teamStatId)#\(e.playerNumber ?? -1)#\(e.playerLast)"
            tally[key, default: 0] += 1
            counts[e.id] = tally[key]
        }
        return counts
    }

    /// Builds the period-grouped rows, preserving the feed's period order (newest first).
    static func build(
        events: [PlayByPlayEvent],
        teams: [PlayByPlayTeam],
        longNameStats: [String: String]
    ) -> [PlayByPlayPeriod] {
        let sideMap = sideByTeam(events: events, teams: teams)
        let foulMap = foulCounts(events: events)
        // teams[0] is the left column of the header; orient every row's score to it.
        let leftSide: PlayByPlaySide = teams.first.flatMap { sideMap[$0.id] } ?? .a

        var order: [String] = []
        var grouped: [String: [PlayByPlayRow]] = [:]

        for e in events {
            let foul = e.statName == "pfs" ? foulMap[e.id] : nil
            let (label, kind) = action(for: e.statName, foulCount: foul, longNameStats: longNameStats)
            let leftScore = leftSide == .a ? e.scoreA : e.scoreB
            let rightScore = leftSide == .a ? e.scoreB : e.scoreA
            var emphasis: PlayByPlayEmphasis = .none
            if kind == .scoring, let side = sideMap[e.teamStatId] {
                emphasis = side == leftSide ? .left : .right
            }
            let row = PlayByPlayRow(
                id: e.id,
                playerNumber: e.playerNumber,
                playerFirstName: e.playerFirst,
                playerLastName: e.playerLast,
                teamName: e.teamName,
                teamLogo: e.teamLogo,
                actionLabel: label,
                actionKind: kind,
                leftScore: leftScore,
                rightScore: rightScore,
                emphasis: emphasis
            )
            if grouped[e.period] == nil { order.append(e.period) }
            grouped[e.period, default: []].append(row)
        }

        return order.map { PlayByPlayPeriod(id: $0, title: periodTitle($0), rows: grouped[$0] ?? []) }
    }
}
