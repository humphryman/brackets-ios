# Bracket slot placement via `bracket_id` — design

**Date:** 2026-05-11
**Status:** Approved for implementation
**Scope:** iOS app (`Brackets`) — `Game.swift`, `BracketView.swift`

## Problem

The bracket today places quarterfinal games by inferring seed pairs from standings (1v8, 4v5, 2v7, 3v6) and matching games against those seeds by team id/name. Semifinal and Final games are matched by propagated team identity from previous rounds. This is brittle when the real bracket pairing doesn't follow the canonical seeding (e.g., admin reorders matchups manually) and forces the iOS app to duplicate the bracket-building logic that lives on the server.

The API now returns a `bracket_id` field on each `Game` that explicitly tells the client which slot the game occupies within its stage. The app should consume that field as the source of truth and stop inferring pairings.

A third-place game (`stage: "Tercer Lugar"`) is also new in the data model and should be displayed under the Final.

## API contract

`Game` gains one optional field:

```json
{
  "id": 123,
  "stage": "Cuartos de Final",
  "bracket_id": 1,
  ...
}
```

- `bracket_id: Int?` — slot index within the stage, 1-based, top-to-bottom.
  - `"Cuartos de Final"`: 1–4
  - `"Semifinal"` / `"Semifinales"`: 1–2
  - `"Final"`: 1 (only one game)
  - `"Tercer Lugar"`: 1 (only one game)
- `null` or absent for games that haven't been assigned a slot, or for games on legacy tournaments where the field hasn't been backfilled.

## User-facing behavior

### Slot placement (strict)

Each slot in the bracket renders one of:

1. **Real game data** — if a game exists with matching `stage` and `bracketId`, that game's teams, scores, and winner status are shown. The card is tappable; tapping pushes `GameResultView` or `UpcomingGameView` as today.
2. **Propagated teams** — if no game matches the slot, but previous-round winners (or losers, for Tercer Lugar) can be derived, show those team names + logos with no score. Not tappable.
3. **TBD** — if neither, show the placeholder logo + `"TBD"` text on both sides.

A game with `bracket_id == null` does not appear in the bracket. Strict mode. This is a deliberate trade-off: legacy data without `bracket_id` shows all-TBD; admins must backfill.

### Propagation

When a slot has no scheduled game, fill its `homeTeam` / `awayTeam` from previous-round results:

| Next-round slot | Pulls from |
|---|---|
| SF slot 1 | (QF slot 1 winner, QF slot 2 winner) |
| SF slot 2 | (QF slot 3 winner, QF slot 4 winner) |
| Final slot 1 | (SF slot 1 winner, SF slot 2 winner) |
| Tercer Lugar slot 1 | (SF slot 1 **loser**, SF slot 2 **loser**) |

Propagation only fills team names — no scores, no winner highlighting, no navigation link. If a previous-round matchup has no completed winner (e.g., game not finished), the propagated value is nil and renders as TBD.

### Layout

- **Round columns** unchanged: QF | SF | Final (3 columns for QF-type tournaments, paged) or SF | Final (2 columns for SF-type tournaments, static).
- **Top header row** unchanged: round names only.
- **Final column** stacks two cards vertically:
  - Final matchup card on top.
  - A small `"3er Lugar"` label below (same style as the top round headers — `size: 11, weight: .bold, color: white 0.45, uppercase`).
  - Tercer Lugar matchup card under the label.
- **No connector lines** between the Final and Tercer Lugar cards. The Tercer Lugar slot is always present (per design choice; some tournaments without a third-place game will show TBDs there indefinitely).

### Empty state

If `games.isEmpty` (no games at all on the schedule), show the existing `"No hay bracket disponible."` empty state. Otherwise render the bracket structure — even if every slot is TBD.

## Implementation

### `Brackets/Game.swift`

Add property and decoder line:

```swift
struct Game: Identifiable, Sendable {
    // ... existing fields ...
    let stage: String?
    let bracketId: Int?              // new

    enum CodingKeys: String, CodingKey {
        // ... existing keys ...
        case stage
        case bracketId = "bracket_id" // new
    }
}
```

And inside the custom `init(from:)`:

```swift
bracketId = try container.decodeIfPresent(Int.self, forKey: .bracketId)
```

No other code in `Game.swift` changes.

### `Brackets/BracketView.swift`

**`BracketRound`** gains an optional `thirdPlace` carry-along:

```swift
struct BracketRound: Identifiable {
    let name: String
    let matchups: [BracketMatchup]
    var thirdPlace: BracketMatchup? = nil
    var id: String { name }
}
```

**New helpers** (replace the seed/team-matching helpers):

```swift
private func stageMatches(gameStage: String, target: String) -> Bool {
    let g = gameStage.lowercased(); let t = target.lowercased()
    if t == "final" { return g == "final" }
    if t == "semifinal" { return g == "semifinal" || g == "semifinales" }
    return g == t
}

private func gameForSlot(stage: String, slot: Int) -> Game? {
    games.first { game in
        guard let gameStage = game.stage, stageMatches(gameStage: gameStage, target: stage) else { return false }
        return game.bracketId == slot
    }
}

private func propagatedPair(from previous: [BracketMatchup], slotIndex: Int, useLoser: Bool) -> (home: Team?, away: Team?) {
    // For next-round slot `slotIndex` (0-based), source from previous matchups slotIndex*2 and slotIndex*2 + 1.
    let aIdx = slotIndex * 2
    let bIdx = aIdx + 1
    let a = aIdx < previous.count ? previous[aIdx] : nil
    let b = bIdx < previous.count ? previous[bIdx] : nil
    return (
        home: a.flatMap { useLoser ? loser(of: $0) : winner(of: $0) },
        away: b.flatMap { useLoser ? loser(of: $0) : winner(of: $0) }
    )
}

private func winner(of matchup: BracketMatchup) -> Team? {
    if matchup.homeIsWinner { return matchup.homeTeam }
    if matchup.awayIsWinner { return matchup.awayTeam }
    return nil
}

private func loser(of matchup: BracketMatchup) -> Team? {
    if matchup.homeIsWinner { return matchup.awayTeam }
    if matchup.awayIsWinner { return matchup.homeTeam }
    return nil
}

private func buildMatchup(stage: String, slot: Int, propagation: (home: Team?, away: Team?)?) -> BracketMatchup {
    if let game = gameForSlot(stage: stage, slot: slot) {
        return BracketMatchup(
            homeTeam: game.homeTeam,
            homeScore: game.homeScore,
            homeIsWinner: game.isFinished && game.winner?.id == game.homeTeam?.id,
            awayTeam: game.awayTeam,
            awayScore: game.awayScore,
            awayIsWinner: game.isFinished && game.winner?.id == game.awayTeam?.id,
            hasGame: true,
            game: game
        )
    }
    return BracketMatchup(
        homeTeam: propagation?.home,
        homeScore: nil,
        homeIsWinner: false,
        awayTeam: propagation?.away,
        awayScore: nil,
        awayIsWinner: false,
        hasGame: false,
        game: nil
    )
}
```

**Top-level `buildRounds`:**

```swift
private func buildRounds() -> [BracketRound] {
    let bracketType = tournament.bracketType?.lowercased() ?? ""

    var rounds: [BracketRound] = []
    var previous: [BracketMatchup] = []

    // QF round (only for quarterfinals-type tournaments)
    if bracketType == "quarterfinals" {
        let qfMatchups = (1...4).map { slot in
            buildMatchup(stage: "Cuartos de Final", slot: slot, propagation: nil)
        }
        rounds.append(BracketRound(name: "Cuartos de Final", matchups: qfMatchups))
        previous = qfMatchups
    }

    // SF round (always present)
    let sfMatchups = (1...2).map { slot in
        let prop = previous.isEmpty
            ? nil
            : propagatedPair(from: previous, slotIndex: slot - 1, useLoser: false)
        return buildMatchup(stage: "Semifinal", slot: slot, propagation: prop)
    }
    rounds.append(BracketRound(name: "Semifinal", matchups: sfMatchups))

    // Final + Tercer Lugar (combined column)
    let finalProp = propagatedPair(from: sfMatchups, slotIndex: 0, useLoser: false)
    let finalMatch = buildMatchup(stage: "Final", slot: 1, propagation: finalProp)

    let thirdProp = propagatedPair(from: sfMatchups, slotIndex: 0, useLoser: true)
    let thirdMatch = buildMatchup(stage: "Tercer Lugar", slot: 1, propagation: thirdProp)

    rounds.append(BracketRound(name: "Final", matchups: [finalMatch], thirdPlace: thirdMatch))

    return rounds
}
```

**`roundColumn` update** — render Tercer Lugar under the Final card:

```swift
VStack(spacing: spacing) {
    ForEach(Array(round.matchups.enumerated()), id: \.offset) { _, matchup in
        matchupCard(matchup: matchup)
    }

    if let third = round.thirdPlace {
        Spacer().frame(height: 16)
        Text("3er Lugar")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(Color(white: 0.45))
            .frame(width: matchupCardWidth, alignment: .center)
        Spacer().frame(height: 6)
        matchupCard(matchup: third)
    }
}
```

**Empty state** — change the guard in `body` from `rounds.isEmpty` to `games.isEmpty`.

**`loadGames`** — drop the standings fetch:

```swift
private func loadGames() async {
    isLoading = true
    errorMessage = nil
    do {
        let response = try await APIService.shared.fetchGamesResponse(for: tournament.id)
        games = response.allGames
        isLoading = false
    } catch {
        errorMessage = error.localizedDescription
        isLoading = false
    }
}
```

**Removed code (in the same commit):**

- `@State private var standings: [TeamStanding] = []`
- `buildQuarterfinalsBracket()`
- `buildStageRounds(_:)`
- `buildRoundWithWinners(stage:name:expectedMatchups:previousMatchups:)`
- `teamFromSeed(_:)`
- `findGame(teamA:teamB:in:)`
- `gamesForStage(_:)`
- Debug `print` statements inside the QF builder (lines 392–395, 403).

## Acceptance

- A QF-type tournament with `bracket_id` populated on each game renders matchups in the exact slots the API specifies, regardless of standings order.
- A QF-type tournament with zero games shows TBD across all rounds.
- A QF-type tournament mid-progress (QF complete, SF not scheduled) shows SF slots with propagated QF winners, Final/Tercer Lugar with TBD (since SF winners/losers are nil yet).
- A SF-type tournament works identically, just without the QF column.
- A tournament with a `"Tercer Lugar"` game shows that game in the Tercer Lugar slot under the Final.
- A tournament without a `"Tercer Lugar"` game still shows the Tercer Lugar slot with TBD/propagated losers.
- Legacy tournaments with all `bracket_id == null` show an all-TBD bracket (visible structurally) and do not crash.
- Tapping a slot with a real game still navigates correctly to `GameResultView` (finished) or `UpcomingGameView` (upcoming).
- Tapping a propagated or TBD slot does nothing (no nav link).

## Out of scope

- No changes to the Games tab, Standings, or any other view.
- No server changes — the API contract is the spec.
- No data migration of legacy tournaments. Admins backfill `bracket_id` as they choose.
