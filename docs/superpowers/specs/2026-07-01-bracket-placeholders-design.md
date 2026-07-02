# Bracket Placeholders (scheduled time / venue / seeds) — Design

**Date:** 2026-07-01
**Files:** `Brackets/Game.swift` (model), `Brackets/BracketView.swift` (matchup model + build + card). No API changes.

**Depends on:** the `multi-bracket-tabs` branch (provides `BracketInfo`, `selectedBracket`,
per-bracket rendering). This work builds on top of it.

## Goal

Fill in bracket matchups that have no created game yet using the `game_placeholders`
data already present in each bracket's metadata: show the seed labels (`team_a`/`team_b`),
and the scheduled date/time + venue, keyed by `stage` + `bracket_id`.

## 1. Model (`Game.swift`)

Add:

```swift
struct GamePlaceholder: Codable, Sendable {
    let stage: String?
    let bracketId: Int?
    let teamA: String?
    let teamB: String?
    let gameTime: Date?
    let venue: Venue?

    enum CodingKeys: String, CodingKey {
        case stage
        case bracketId = "bracket_id"
        case teamA = "team_a"
        case teamB = "team_b"
        case gameTime = "game_time"
        case venue
    }
}
```

`BracketInfo` gains `let gamePlaceholders: [GamePlaceholder]?` with `case gamePlaceholders =
"game_placeholders"` in its `CodingKeys`. The games response decoder's existing `.custom`
`dateDecodingStrategy` (APIService.fetchGamesResponse) applies to all nested `Date` values, so
`gameTime` parses from `"2026-07-01T14:00:00.000"` with no extra work. `Venue` is the existing
model (already tolerates `court`/`name`/`lat`/`lng`). Both new members are optional, so
brackets without `game_placeholders` decode fine.

## 2. Matchup model (`BracketView.swift`)

`BracketMatchup` gains four fields (all defaulted so existing construction sites are
unaffected):

```swift
    var homePlaceholder: String? = nil
    var awayPlaceholder: String? = nil
    var scheduledTime: Date? = nil
    var venue: Venue? = nil
```

## 3. Placement logic (`BracketView.swift`)

New helper:

```swift
    private func placeholderForSlot(stage: String, slot: Int) -> GamePlaceholder? {
        selectedBracket?.gamePlaceholders?.first { ph in
            guard let phStage = ph.stage else { return false }
            return stageMatches(gameStage: phStage, target: stage) && ph.bracketId == slot
        }
    }
```

(`selectedBracket` is nil for legacy single-bracket tournaments with no `brackets` array, so
they get no placeholders and keep the current "TBD" behavior.)

`buildMatchup(stage:slot:propagation:)` becomes:
- **Actual game found** (`gameForSlot` non-nil) → build from the game as today
  (real teams / scores / winner); set `scheduledTime = game.gameTime`, `venue = game.venue`.
- **No game** → look up `placeholderForSlot`. Teams follow **real-advancing → seed → TBD**:
  - `homeTeam`/`awayTeam` = the propagated real team (winner advancing from a played prior
    round), unchanged from today.
  - `homePlaceholder` = `propagation?.home == nil ? placeholder?.teamA : nil`;
    `awayPlaceholder` = `propagation?.away == nil ? placeholder?.teamB : nil` (seed label used
    only when there's no real team).
  - `scheduledTime = placeholder?.gameTime`, `venue = placeholder?.venue`.

`teamRow` renders the name as `team?.name ?? placeholderName ?? "TBD"`. When shown from a
placeholder label (no real `Team`), it renders like the current no-team state: dimmed text,
placeholder logo, not a winner.

## 4. Card footer + layout (`BracketView.swift`)

Add a compact footer to `matchupCard`, below the two team rows, shown whenever
`matchup.scheduledTime != nil`:
- Line 1: date + time, `es_MX`, `AppConfig.DateTime.apiTimeZone`, format `d MMM · h:mm a`
  (e.g. `1 jul · 2:00 PM`), small gray text.
- Line 2: `venue.name` (small gray, single line, truncating).

Because the connector geometry derives from `matchupCardHeight`, keep all cards a **uniform
explicit height**:
- Give the card `.frame(width: matchupCardWidth, height: matchupCardHeight)`.
- Bump `matchupCardHeight` from `110` to `140` to fit the footer.
- `connectorPair`, `matchupSpacing`, and `topPadding` already read `matchupCardHeight`, so the
  tree re-aligns automatically. `connectorWidth`/`matchupCardWidth` unchanged.

**Footer visibility decision:** the footer shows whenever `scheduledTime` exists, sourced from
the game when present else the placeholder. This means game cards (including finished ones)
also show their date + venue, not only placeholders. This is intentional (consistent,
informative). If we later want it placeholder-only, gate the footer content on
`matchup.game == nil` while keeping the reserved height so the tree stays aligned.

## 5. Scope

- `Game.swift`: `GamePlaceholder` + `BracketInfo.gamePlaceholders`.
- `BracketView.swift`: four `BracketMatchup` fields; `placeholderForSlot`; `buildMatchup`
  precedence + scheduledTime/venue; `teamRow` name fallback; `matchupCard` footer; explicit
  card height + `matchupCardHeight = 140`.
- Unchanged: bracket tabs, round sequence/Octavos, connector formulas (only the height
  constant changes), live badge, navigation, games/standings views.

## Out of scope

- No API changes. No new detail screen (placeholder info lives on the card footer).
- No persistence. Placeholder matchups remain non-tappable (no game to open).
- Seed-label styling beyond the existing dimmed no-team appearance.
