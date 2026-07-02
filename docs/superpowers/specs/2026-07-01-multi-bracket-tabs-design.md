# Multi-Bracket View with Tabs — Design

**Date:** 2026-07-01
**Files:** `Brackets/Game.swift` (model), new `Brackets/ChipCarousel.swift` (shared), `Brackets/GamesListView.swift` (swap to shared carousel), `Brackets/BracketView.swift` (tabs + multi-bracket). No API changes.

**Depends on:** the `games-view-redesign` branch (provides `Game.bracket`/`Game.bracketId`, `BracketInfo`, `GamesResponse.brackets`, and the carousel being extracted). This work builds on top of that branch.

## Goal

Support multiple brackets in the Bracket tab. Add a tab bar (the games-view chip
carousel) listing every bracket the API returns; the selected bracket renders with the
existing bracket logic, filtered to that bracket's games. Each bracket's round depth is
driven by its `type` (`octavos` / `quarterfinals` / `semifinals`), adding Octavos as a new
first round.

## 1. Model — `BracketInfo.type` (`Game.swift`)

`BracketInfo` currently decodes `name`, `position`, `typeLabel`. Add:

```swift
    let type: String?   // "octavos" | "quarterfinals" | "semifinals"
```

with `case type` added to its `CodingKeys`. `Game.bracket` (name) and `Game.bracketId`
(slot) already decode. No other model changes.

## 2. Shared carousel — extract `ChipCarousel` (new `ChipCarousel.swift`)

Extract the games-view carousel into a generic, reusable component that keeps the exact
current visuals and behavior:

```swift
struct ChipCarousel<Item: Hashable>: View {
    let items: [Item]
    let label: (Item) -> String
    @Binding var selected: Item?
    // ...
}
```

- Rendering: horizontal chip row inside `ScrollViewReader`; each chip is a capsule —
  selected = clear fill + 2.5pt accent stroke + white text; unselected = `Color(white: 0.08)`
  fill + `Color(white: 0.83)` text. `ForEach(items, id: \.self)`, chip `.id(label(item))`.
- Overflow arrows: HStack layout `[‹] [scroll area] [›]`; both arrows shown together when the
  content overflows the viewport (`isOverflowing`); arrow = `Color(white: 0.14)` circle,
  `Color(white: 0.83)` chevron; tapping advances/retreats a tracked `leadingIndex` by ~one
  viewport and `proxy.scrollTo(label(items[leadingIndex]), anchor: .leading)`. `leadingIndex`
  resets to 0 when `items` changes. Content-width / viewport-width captured via the two
  existing `PreferenceKey`s. `.frame(height: 44)`.

Keep the `CarouselContentWidthKey` / `CarouselContainerWidthKey` preference keys (move them
into `ChipCarousel.swift`).

**Games view rewire (`GamesListView.swift`):** delete `struct GroupFilterCarousel` and the
two carousel preference keys (now in `ChipCarousel.swift`); replace the usage
`GroupFilterCarousel(chips: chips, selected: $selectedChip)` with
`ChipCarousel(items: chips, label: \.name, selected: $selectedChip)`. `GameGroupChip` must be
`Hashable` (it's already `Equatable`; add `Hashable` — all stored fields are `Hashable`).
Behavior is unchanged; re-verify the games view.

## 3. Bracket state & per-bracket game filtering (`BracketView`)

Add state:

```swift
    @State private var brackets: [BracketInfo] = []
    @State private var selectedBracketName: String?
    @State private var didInitBracket = false
```

`loadGames` captures both games and brackets (sorted by `position`, nil `position` last), and
on first load selects the first bracket's name:

```swift
    let response = try await APIService.shared.fetchGamesResponse(for: tournament.id)
    games = response.allGames
    brackets = (response.brackets ?? []).sorted { ($0.position ?? .max) < ($1.position ?? .max) }
    if !didInitBracket {
        selectedBracketName = brackets.first?.name
        didInitBracket = true
    }
```

Selection helpers:
- `selectedBracket: BracketInfo?` = `brackets.first { $0.name == selectedBracketName }`.
- `bracketGames: [Game]` = when a bracket is selected, `games.filter { $0.bracket == selectedBracketName }`; when `brackets` is empty (legacy single-bracket tournaments), all `games`.
- `activeType: String` = `selectedBracket?.type ?? tournament.bracketType ?? ""`.

Tab-bar visibility:
- `brackets.count >= 2` → show the `ChipCarousel` (items = `brackets.map(\.name)`, selected =
  `$selectedBracketName`) above the bracket body.
- `brackets.count <= 1` → no tab bar; render the single/legacy bracket.

Switching tabs resets `currentPage = 0` (and `dragOffset = 0`) via `.onChange(of: selectedBracketName)`.

`rounds` is computed from `buildRounds(type: activeType, bracketGames: bracketGames)`.

## 4. Round builder — generalize + add Octavos (`BracketView`)

Refactor `buildRounds`, `gameForSlot`, `matchupSpacing` to take the active `type` and the
filtered `bracketGames` as parameters instead of reading `tournament.bracketType` and the
global `games`. Round sequence by type (each halves down to Final + Tercer Lugar):

| type | rounds |
|------|--------|
| `octavos` | Octavos (8 slots) → Cuartos (4) → Semifinal (2) → Final (1) + 3º |
| `quarterfinals` | Cuartos (4) → Semifinal (2) → Final (1) + 3º |
| `semifinals` (or unknown) | Semifinal (2) → Final (1) + 3º |

- New Octavos round: `stage = "Octavos de final"`, slots `1...8`, `buildMatchup` per slot,
  propagating winners into Cuartos via the existing `propagatedPair`. `stageMatches` already
  matches by lowercased equality (`"octavos de final" == "octavos de final"`).
- `gameForSlot(stage:slot:)` filters within `bracketGames` (not global `games`) and matches
  `bracketId == slot`; single-slot stages (Final, Tercer Lugar) keep the "lone game" shortcut.
  Because games are pre-filtered by bracket, `bracketId` slots no longer collide across
  brackets.
- `matchupSpacing` base uses `type == "semifinals" ? 80 : 24` (as today), now with the active
  type. The recursive spacing/`topPadding` and the pager (`needsPaging = rounds.count > 2`)
  already handle a 4-column (octavos) bracket.

## 5. Misc correctness

- **`makeUpdatedGame`** rebuilds `Game(...)` and currently omits `group`/`bracket`, which would
  drop a live game's bracket name and remove it from its tab. Add `group: original.group,
  bracket: original.bracket` to the constructed `Game`.
- Live refresh continues to operate on all `games`; the selected bracket re-derives from the
  updated set.

## 6. Scope

- `Game.swift`: add `BracketInfo.type`.
- New `Brackets/ChipCarousel.swift`: generic carousel + its two preference keys.
- `GamesListView.swift`: delete `GroupFilterCarousel` + moved preference keys; use
  `ChipCarousel`; make `GameGroupChip: Hashable`.
- `BracketView.swift`: bracket state + tab bar, per-bracket filtering, generalized round
  builder + Octavos, `makeUpdatedGame` fix.
- Unchanged: matchup card visuals, connector lines, live badge, navigation destinations,
  standings, all other views.

## Out of scope

- No API changes. No changes to game detail screens or standings.
- No persistence of the selected bracket across launches (in-memory only).
- Bracket types beyond octavos/quarterfinals/semifinals (e.g. round-of-32) are not added.
