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
    /// Lowercase words that glue two halves of one name together — the "del" in
    /// "Martin del Campo". They can open a name ("Del Río Soto") or sit inside it, and
    /// either way the name does not end until the word after them.
    private static let linkers: Set<String> = [
        "de", "del", "la", "las", "le", "los", "el", "da", "das", "do", "dos",
        "di", "della", "du", "van", "von", "der", "den", "ten", "ter"
    ]

    /// Words that only ever *open* a name. "San Miguel Pérez" is San Miguel, but
    /// "López San Miguel" is two surnames and the first one is López — so unlike a
    /// linker, one of these never pulls itself onto the name before it.
    private static let openers: Set<String> = ["san", "santa", "st"]

    /// Generational suffixes. These belong to the person rather than to a family
    /// name, so they survive the trim and never count as one of the two names shown.
    /// Matched without punctuation, so "Jr", "Jr." and "JR" all land here.
    private static let suffixes: Set<String> = [
        "jr", "sr", "junior", "senior", "ii", "iii", "iv", "v"
    ]

    /// The first name in `name` — with the particles that hold it together and any
    /// generational suffix that trails it.
    /// "Juan Carlos" → "Juan"; "Martin del Campo Guzmán" → "Martin del Campo";
    /// "de la Cruz Peña" → "de la Cruz"; "Pérez Gómez Jr" → "Pérez Jr"; "" → "".
    static func first(_ name: String) -> String {
        let words = name.split(whereSeparator: \.isWhitespace)
        var kept: [Substring] = []
        var index = 0

        while index < words.count {
            let word = words[index]
            kept.append(word)
            index += 1

            // A particle is never the end of a name: whatever follows belongs to it.
            if isParticle(word) { continue }
            // And a name is not over while a linker is waiting to join it to the next
            // word — that is what makes "Martin del Campo" one surname and not two.
            if index < words.count, isLinker(words[index]) { continue }

            break
        }

        guard !kept.isEmpty else { return "" }

        // The suffix follows the name it belongs to ("Pérez Jr Gómez"), but it is just
        // as often parked at the end of the whole field ("Pérez Gómez Jr"). Either way
        // it is the one extra word worth carrying: it is how the player is told apart
        // from the relative they share a name with.
        let rest = words.dropFirst(kept.count)
        if let next = rest.first, isSuffix(next) {
            kept.append(next)
        } else if let last = rest.last, isSuffix(last) {
            kept.append(last)
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
        // Neither a particle nor a "Jr" is what an avatar should be filed under.
        let words = name
            .split(whereSeparator: \.isWhitespace)
            .filter { !isParticle($0) && !isSuffix($0) }

        guard let head = words.first else { return "" }
        guard let tail = words.dropFirst().last else {
            return String(head.prefix(2)).uppercased()
        }

        return String(head.prefix(1) + tail.prefix(1)).uppercased()
    }

    /// Whether `word` joins the name that follows it, in any position.
    private static func isLinker(_ word: Substring) -> Bool {
        linkers.contains(folded(word))
    }

    /// Whether `word` introduces a name rather than being one — a linker or an opener.
    private static func isParticle(_ word: Substring) -> Bool {
        let folded = folded(word)
        return linkers.contains(folded) || openers.contains(folded)
    }

    /// Whether `word` is a generational suffix, ignoring the trailing dot or comma
    /// the API sometimes carries ("Jr.", "Jr,").
    private static func isSuffix(_ word: Substring) -> Bool {
        suffixes.contains(folded(word).trimmingCharacters(in: CharacterSet(charactersIn: ".,")))
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
