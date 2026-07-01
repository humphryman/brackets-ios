# Games View Redesign — Design

**Date:** 2026-07-01
**Files:** `Brackets/Game.swift` (model), `Brackets/GamesListView.swift` (view). No API changes.

## Goal

Redesign the Games list to match the provided mockups: a two-row filter (top
Próximos/Resultados tab + a scrollable group/bracket chip carousel with arrows),
a per-date header with a game count, and a unified dark game card with a location
row and stage/group tags. Final and Semifinal games get a colored top banner.

## 1. Model changes (`Game.swift`)

Add two fields to `Game`, decoded from the existing games JSON:

- `group: String?` — e.g. `"Grupo 4"`. `decodeIfPresent`. `null` for playoff games.
- `bracket: String?` — e.g. `"Playoffs"`, `"Playoffs 2"`. `decodeIfPresent`. `null` for regular games.

Add `CodingKeys` entries `case group` and `case bracket`, and decode both in
`init(from:)`.

Add to `GamesResponse` an optional bracket-ordering list decoded from the top-level
`"brackets"` array:

```swift
struct BracketInfo: Codable, Sendable {
    let name: String
    let position: Int?
    let typeLabel: String?
    enum CodingKeys: String, CodingKey {
        case name, position
        case typeLabel = "type_label"
    }
}
```

`GamesResponse` gains `let brackets: [BracketInfo]?` (`decodeIfPresent`, key `"brackets"`),
used only to order bracket chips. Existing `games` decoding is unchanged.

## 2. Top filter (`GameFilter`)

Remove the `.all` ("Todos") case entirely. Remaining: `.upcoming` ("Próximos"),
`.completed` ("Resultados"), and `.live` ("En Vivo") shown only when live games exist.

- Default `selectedFilter`: `.live` if live games exist, else `.upcoming`.
- Update `availableFilters` (drop `.all`), `filteredGames` (drop the `.all` branch),
  and `startLiveRefreshIfNeeded` / `refreshLiveGames` (they currently fall back to
  `.all`; fall back to `.upcoming` instead).

## 3. Group/bracket filter carousel (new `GroupFilterCarousel`)

A second row beneath the top filter.

**Chip model:**
```swift
struct GameGroupChip: Identifiable, Equatable {
    enum Kind { case group, bracket }
    let name: String   // "Grupo 1" or "Playoffs"
    let kind: Kind
    var id: String { "\(kind == .group ? "g" : "b")-\(name)" }
}
```

**Chip list** (computed from the loaded response, stable across top-tab changes):
- Group chips: distinct non-null `game.group`, **natural numeric sort** by the trailing
  integer (`Grupo 1, 2, …, 13`), NOT lexical (`Grupo 1, 10, 11, 2`). Sort key: parse the
  number after the last space; fall back to string compare.
- Bracket chips: distinct non-null `game.bracket` that have games, ordered by
  `GamesResponse.brackets` `position` (ascending); brackets absent from that list, or when
  `brackets` is nil, are appended in first-appearance order. Appended after all group chips.

**Selection:** exactly one chip is always selected (no "Todos"). State: `selectedChip: GameGroupChip?`.
- On first successful load, and whenever the top tab changes, if `selectedChip` is nil or has
  no games under the active top-tab, auto-select the first chip (in chip order) that does.
- A game belongs to a chip when: `chip.kind == .group && game.group == chip.name`, or
  `chip.kind == .bracket && game.bracket == chip.name`.

**Chip style** (matches mockup): selected = capsule with **accent (lime) stroke**, no fill,
white text; unselected = capsule filled `Color(white: 0.15)`, white text. Horizontal padding
16, vertical 8.

**Carousel arrows:** the chip row is a horizontal `ScrollView(.horizontal)` inside a
`ScrollViewReader`. Overflow is measured with a `GeometryReader` on the content plus a
`PreferenceKey` reporting content width vs. the container width.
- Right circular chevron button appears when the row can scroll further right (content wider
  than viewport and not at the end); left button appears once scrolled away from the start.
- Button style: `Circle().fill(Color(white: 0.15))`, ~34pt, `chevron.right`/`chevron.left`
  in white. Tapping scrolls the row forward/back by roughly one viewport width via
  `proxy.scrollTo(chipId, anchor:)`, tracking the current leading chip index.
- When everything fits, no arrows are shown.

## 4. Date header

For each date group (after filtering): calendar icon (`calendar`, accent) + the date
formatted `EEEE, d 'de' MMMM` in `es_MX`, `.capitalized` → **"Jueves, 18 de Junio"**, followed
by a gray pill badge **"N Juegos"** (N = games in that date group after filtering; use
`"1 Juego"` singular when N == 1). Badge: `Color(white: 0.2)` capsule, `secondaryText`.

**Sort:** upcoming and live date groups ascending (nearest first); completed descending
(latest first). Keep the existing `scrollToInitialPosition` jump-to-nearest-future behavior
for upcoming/live.

## 5. Card redesign (`GameCard`, `TeamSection`, `CenterSection`)

One unified dark card (`Color(white: 0.11)`, `CornerRadius.large`, clipped) for both scored
and upcoming games. No per-card special background colors or borders (replaced by the banner
below).

**Optional top banner** (full-width strip, rounded top via card clip, label left-aligned,
bold, `padding(.horizontal 14, .vertical 8)`):
- `stage.lowercased() == "final"` → text **"Final"**, fill `AppTheme.Colors.accent`, text
  `AppTheme.Colors.accentText` (black).
- `stage.lowercased()` contains `"semifinal"` (also matches "Semifinales") → text
  **"Semifinal"**, fill `Color(red: 0.23, green: 0.21, blue: 0.90)` (blue), white text.
- Otherwise no banner.

**Body** (`padding` ~16):
- **Teams (left/right), name below logo, centered.** Winner (`game.isFinished && winner.id ==
  team.id`) gets a lime ring around the logo; loser plain. Reuse the existing logo/initials
  circle approach.
- **Center:** finished → `homeScore - awayScore`, the **winner's number in accent green**,
  loser/tie in white, dash in gray; upcoming → the **time** (`h:mm a`, es timezone) in white
  bold. No "VS"; no date inside the card.
- **Location:** centered, reuse `VenueLabel(venue:)` (green `mappin.and.ellipse` + green text,
  Maps link when coords exist). Only when `game.venue != nil`.
- **Tags row (centered, spacing 8):**
  - Left **stage** gray pill (`Color(white: 0.2)` fill, light text) — shown only when there is
    **no banner** (avoids "Final"/"Semifinal" appearing twice). Text = `stage.capitalized`.
  - Right **group/bracket** purple pill (`Color(red: 0.45, green: 0.31, blue: 0.82)` fill,
    white text). Text = `game.group ?? game.bracket`. Omitted when both are nil.

So: regular game → gray "Ronda Regular" + purple "Grupo 1". Cuartos/Octavos/Tercer Lugar →
gray stage + purple "Playoffs". Final/Semifinal → banner + purple "Playoffs" (no gray tag).

## 6. Filtering & list assembly (`GamesListView`)

`filteredGames` = for each date group, keep games where the game matches BOTH the active top
filter (existing `.upcoming`/`.completed`/`.live` predicates) AND the `selectedChip`. Drop
empty date groups; sort per §4.

State added: `selectedChip: GameGroupChip?`, plus a `didInitChip` guard for first-load
selection. Chip auto-reselect runs on load and on `selectedFilter` change.

## 7. Scope

- Model edits: `Game.swift` (`group`, `bracket`, `BracketInfo`, `GamesResponse.brackets`).
- View: `GamesListView.swift` — `GameFilter` (drop `.all`), filtering/state, date header +
  count badge, redesigned `GameCard`/`TeamSection`/`CenterSection`, new `GameGroupChip` +
  `GroupFilterCarousel`.
- Unchanged: `LiveGameCard` (red-bordered live card), navigation destinations
  (`UpcomingGameView` / `GameResultView` / `LiveGameDetailView`), all other views.

## Out of scope

- No API changes. No changes to game detail screens or the Bracket tab.
- No persistence of the selected chip across launches (in-memory only).
