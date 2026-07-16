# Multiple Podiums in the "Campeón" Tab

**Date:** 2026-07-15
**Status:** Approved design, ready for implementation plan

## Summary

The standings endpoint (`/tournaments/{id}/standings.json`) will return a new
`podiums` array — a list of per-bracket podiums (e.g. Gold, Silver, Bronze), each
with its own 1st/2nd/3rd place. The app's "Campeón" tab must display one podium at
a time, with a Gold/Silver/Bronze selector reusing the same pill carousel the
Brackets tab already uses.

The current singular `podium` key is dropped entirely — the app no longer reads it.

### Example payload (new `podiums` key)

```json
"podiums": [
  {
    "bracket_id": 43, "position": 1, "name": "Gold",
    "type": "quarterfinals", "type_label": "Cuartos",
    "first":  { "place": 1, "team_id": 417, "team_season_id": 890, "team_name": "Gladiadores Valle", "team_logo": null },
    "second": { "place": 2, "team_id": 436, "team_season_id": 909, "team_name": "Pingüinos Sierra", "team_logo": null },
    "third":  { "place": 3, "team_id": 453, "team_season_id": 926, "team_name": "Cometas Azteca", "team_logo": null }
  },
  { "bracket_id": 44, "position": 2, "name": "Silver", "type": "octavos", "type_label": "Octavos de Final", "first": {…}, "second": {…}, "third": {…} },
  { "bracket_id": 45, "position": 3, "name": "Bronze", "type": "octavos", "type_label": "Octavos de Final", "first": {…}, "second": {…}, "third": {…} }
]
```

Each podium item has **no** `tournament_name` (the old singular `podium` did).

## Decisions

| Decision | Choice |
|----------|--------|
| Old singular `podium` key | **Drop entirely.** No fallback. The Campeón tab is driven only by `podiums`. |
| Campeón tab gating | **`podiums` non-empty only.** Decoupled from `tournament.winner`. |
| Single-podium selector | **Always show** the chip row, even with one podium. |
| Panel subtitle | Use `tournament.name` (podium items carry no `tournament_name`). |
| Default landing tab | **Campeón** whenever `podiums` is non-empty. |

## Approach

Reuse existing components rather than build new ones:

- **`ChipCarousel`** (`ChipCarousel.swift`) — the exact capsule-pill selector with
  lime selected-border and overflow chevrons that `BracketView` uses for
  Gold/Silver/Bronze. Generic over `Hashable`; drive it with `[String]` of podium
  names, matching `BracketView`'s usage.
- **`ChampionPanel` / `PodiumCard`** (`StandingsView.swift`) — the podium visuals
  are unchanged; only `ChampionPanel`'s inputs change.

The real work is (1) a new decodable model for the `podiums` array and (2) wiring a
per-bracket selector into the champion tab.

## Changes

### 1. Data model — `APIService.swift`

**Remove:**
- `struct Podium`
- `StandingsResponse.podium`
- `StandingsBundle.podium`

**Add** `BracketPodium`:

```swift
struct BracketPodium: Codable, Sendable, Hashable, Identifiable {
    let bracketId: Int
    let position: Int
    let name: String
    let type: String?
    let typeLabel: String?
    let first: PodiumEntry
    let second: PodiumEntry?
    let third: PodiumEntry?

    var id: Int { bracketId }

    enum CodingKeys: String, CodingKey {
        case position, name, type, first, second, third
        case bracketId = "bracket_id"
        case typeLabel = "type_label"
    }
}
```

**Update wrappers:**
- `StandingsResponse.podiums: [BracketPodium]?` (decoded via `decodeIfPresent`, default synthesized decode is fine since the whole response is `Codable`).
- `StandingsBundle.podiums: [BracketPodium]` (non-optional; default `[]`).
- The three `StandingsBundle(...)` constructions in `fetchStandings` pass
  `podiums: response.podiums ?? []`.
- The direct-array fallback construction passes `podiums: []`.

`PodiumEntry` is unchanged.

### 2. Champion tab gating & default — `StandingsView.swift`

- `hasChampionTab` → `!(bundle?.podiums.isEmpty ?? true)`. No longer references
  `tournament.winner`.
- `init(tournament:)` no longer reads `tournament.winner`; initialize
  `selectedSubTab` to `.standings`.
- Add `@State private var didInitSubTab = false`.
- In `loadStandings`, after `bundle` is set:
  - On first load (`!didInitSubTab`): `selectedSubTab = availableTabs.first ?? .standings`; set `didInitSubTab = true`. Because `availableTabs` lists `.champion` first when present, this defaults to Campeón whenever podiums exist.
  - Preserve the existing safety fallback: if `selectedSubTab` is not in `availableTabs`, set it to `.standings`.

`availableTabs` ordering is unchanged: `[.champion?, .standings, .classification?]`.

### 3. Champion tab content — `StandingsView.swift`

- Add `@State private var selectedPodiumName: String?`.
- Add a computed `sortedPodiums: [BracketPodium]` = `bundle.podiums` sorted by
  `position` ascending.
- Initialize `selectedPodiumName` in `loadStandings` after load: if podiums present
  and `selectedPodiumName == nil`, set it to `sortedPodiums.first?.name`.
- The `.champion` case renders a `VStack(spacing:)`:
  - `ChipCarousel(items: sortedPodiums.map(\.name), label: { $0 }, selected: $selectedPodiumName)` — always shown.
  - `ChampionPanel(podium: resolved, tournamentName: tournament.name)` where
    `resolved = sortedPodiums.first { $0.name == selectedPodiumName } ?? sortedPodiums.first`.
  - If `sortedPodiums` is somehow empty at render (shouldn't happen given gating),
    fall back to `standingsScroll(bundle.result)`.

Layout notes:
- The chip row sits **below** the existing `StandingsSubTabBar`
  (Campeón / Grupos / Clasificación). The mockup is cropped to the champion content.
- The chip row is pinned above `ChampionPanel`'s own `ScrollView`, mirroring how
  `BracketView` pins its `ChipCarousel` above the bracket body.
- `PodiumCard` medal colors stay keyed to `place` (1=gold, 2=silver, 3=bronze),
  independent of the bracket name.

### 4. `ChampionPanel` refactor — `StandingsView.swift`

- Signature → `let podium: BracketPodium` and `let tournamentName: String`.
- Replace `podium.tournamentName` with `tournamentName`.
- `podium.first` / `podium.second` / `podium.third` access and all `PodiumCard`
  usage are unchanged.
- Update the `#Preview` to build a multi-podium sample (Gold/Silver/Bronze) from the
  example JSON above and drive `ChipCarousel` + `ChampionPanel` together.

## Edge cases

- **Empty `podiums`** → `hasChampionTab` false → no Campeón tab, no selector; default
  tab becomes Grupos.
- **Podium with only `first`** (no 2nd/3rd) → existing `ChampionPanel` spacer
  handling already renders the single card centered.
- **Stale `selectedPodiumName`** after a reload where that bracket disappeared →
  resolved via `?? sortedPodiums.first`.
- **Subtitle divergence** — panel subtitle now uses `tournament.name`, which may read
  differently from the old payload's `tournament_name`. Accepted.

## Out of scope

- The champion overlay in `ContentView` (dims the tournament image, shows "CAMPEÓN")
  remains keyed to `tournament.winner` and is not changed.
- `StatsLeadersView`'s own `podiumView` (player-stats podium) is unrelated and
  untouched.

## Verification

No unit-test target exists; verification is manual + previews:

1. Xcode build succeeds (`Brackets` scheme).
2. `ChampionPanel` `#Preview` renders Gold/Silver/Bronze and switching chips swaps
   the podium.
3. Manual: a multi-bracket tournament shows the selector and defaults to Campeón;
   switching Gold/Silver/Bronze updates the three cards.
4. Manual: a single-podium tournament shows exactly one chip and the podium.
5. Manual: a tournament with no `podiums` shows no Campeón tab and lands on Grupos.

## Affected files

- `Brackets/APIService.swift` — model changes, `fetchStandings` construction updates.
- `Brackets/StandingsView.swift` — gating, default tab, selector state, `.champion`
  case, `ChampionPanel` signature, preview.
