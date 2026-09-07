//
//  PlayerName.swift
//  Brackets
//

import Foundation

/// How athlete names are shown across the app: one given name and one surname.
///
/// Rosters carry full legal names — "Juan Carlos", "Reyes Peña" — but every surface
/// (lists, podium, game stats, share cards) shows only the first of each, so a name
/// fits on one line and reads the way the player is actually called. Compound
/// particles stay glued to the name they introduce, so "de la Cruz Peña" shortens to
/// "de la Cruz", not to "de".
enum PlayerName {
    /// Words that lead into the name that follows them instead of standing alone.
    private static let particles: Set<String> = [
        "de", "del", "la", "las", "le", "los", "el", "da", "das", "do", "dos",
        "di", "della", "du", "van", "von", "der", "den", "ten", "ter",
        "san", "santa", "st", "y", "e"
    ]

    /// The first name in `name`, keeping any particles that introduce it.
    /// "Juan Carlos" → "Juan"; "de la Cruz Peña" → "de la Cruz"; "" → "".
    static func first(_ name: String) -> String {
        let words = name.split(whereSeparator: \.isWhitespace)
        var kept: [Substring] = []

        for word in words {
            kept.append(word)
            // A particle only prefixes the word after it; anything else ends the name.
            if !particles.contains(folded(word)) { break }
        }

        return kept.joined(separator: " ")
    }

    /// One given name and one surname: "Juan Carlos", "Reyes Peña" → "Juan Reyes".
    static func short(first firstName: String, last lastName: String) -> String {
        [first(firstName), first(lastName)]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// Initials for the two names shown, skipping particles: "Juan de la Cruz" → "JC".
    /// Falls back to the first two letters when there is only one name to work with.
    static func initials(first firstName: String, last lastName: String) -> String {
        initials(of: short(first: firstName, last: lastName))
    }

    /// Initials of an already-shortened display name — for the places that only ever
    /// receive the joined string.
    static func initials(of name: String) -> String {
        let words = name
            .split(whereSeparator: \.isWhitespace)
            .filter { !particles.contains(folded($0)) }

        guard let head = words.first else { return "" }
        guard let tail = words.dropFirst().last else {
            return String(head.prefix(2)).uppercased()
        }

        return String(head.prefix(1) + tail.prefix(1)).uppercased()
    }

    /// Lowercased and stripped of accents, so "Dé" matches the "de" particle.
    private static func folded(_ word: Substring) -> String {
        word.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }
}

// MARK: - Model conveniences
//
// One pair per model that carries a name from the API. Views read these instead of
// the raw fields so the whole app shortens names the same way.

extension Player {
    var shortFirstName: String { PlayerName.first(firstName) }
    var shortLastName: String { PlayerName.first(lastName) }
    var shortName: String { PlayerName.short(first: firstName, last: lastName) }
    var initials: String { PlayerName.initials(first: firstName, last: lastName) }
}

extension PlayerOfTheGame {
    var shortFirstName: String { PlayerName.first(firstName) }
    var shortLastName: String { PlayerName.first(lastName) }
    var initials: String { PlayerName.initials(first: firstName, last: lastName) }
}

extension PlayerGameStat {
    var shortFirstName: String { PlayerName.first(playerFirstName) }
    var shortLastName: String { PlayerName.first(playerLastName) }
    var shortName: String { PlayerName.short(first: playerFirstName, last: playerLastName) }
    var initials: String { PlayerName.initials(first: playerFirstName, last: playerLastName) }
}

extension StatLeaderEntry {
    var shortFirstName: String { PlayerName.first(firstName) }
    var shortLastName: String { PlayerName.first(lastName) }
    var initials: String { PlayerName.initials(first: firstName, last: lastName) }
}

extension PlayerSeason {
    var shortFirstName: String { PlayerName.first(firstName) }
    var shortLastName: String { PlayerName.first(lastName) }
    var initials: String { PlayerName.initials(first: firstName, last: lastName) }
}
