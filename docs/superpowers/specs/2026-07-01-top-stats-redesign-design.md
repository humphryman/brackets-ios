# Top Stats Redesign — Design

**Date:** 2026-07-01
**Files:** `Brackets/Stats.swift` (models), `Brackets/APIService.swift` (fetch), `Brackets/StatsLeadersView.swift` (restyle), new `Brackets/TopStatDetailView.swift` (full list + filters). No other views changed.

## Goal

Restyle the Top Stats view to the mockup — a per-category card with a title header, a
podium (top 3), a flat ranked list of all returned players, and a green "Ver listado completo"
footer — while keeping the multi-category carousel. The footer opens a new full-leaderboard
screen (separate endpoint) that adds name + team filters over the list.

## 1. Models (`Stats.swift`)

- Add `let rank: Int?` to `PlayerStatEntry`, decoded via `decodeIfPresent` (main `top_stats`
  omits it → nil; the full-list `top_stat` endpoint provides it). Same entry type serves both
  screens.
- Add the full-list response type:

```swift
struct TopStatDetail: Codable, Sendable {
    let stat: String
    let statName: String
    let statShortName: String
    let average: Bool
    let players: [PlayerStatEntry]

    enum CodingKeys: String, CodingKey {
        case stat
        case statName = "stat_name"
        case statShortName = "stat_short_name"
        case average
        case players
    }
}
```

`PlayerStatEntry`'s existing custom `init(from:)` already tolerates string-or-number `score`;
add `rank = try container.decodeIfPresent(Int.self, forKey: .rank)` (and `case rank`).

**Stat key mapping:** a category's `?stat=` key is `category.stats.first?.statName` (the
machine key, e.g. `"points"` — confirmed present per-player in `top_stats.json`).

## 2. API (`APIService.swift`)

```swift
func fetchTopStatDetail(for tournamentId: Int, stat: String) async throws -> TopStatDetail
```
`GET {APIConfig.apiURL}/tournaments/{id}/top_stat.json?stat=<stat>` (URL-encode `stat`), decoded
with the same `JSONDecoder` configuration used by `fetchTopStats` (custom date strategy not
required here but harmless). Throws `APIError` on bad URL/response, like the other fetchers.

## 3. Main screen restyle (`StatsLeadersView`)

Keep the category **carousel** (`TabView(.page)`) + page-dot indicator. Each category page
becomes a single card (dark `Color(white: 0.1)`, radius `AppTheme.CornerRadius.large`):

- **Title header:** `category.name` centered, `size 18 bold`, `primaryText`, with a
  `Color(white: 0.2)` divider beneath.
- **Podium (top 3):** center #1 photo larger with a **green ring** (`accent`) + **green crown**
  above; #2 left / #3 right smaller. **Green circular rank badge** (accent fill, `accentText`
  number) overlapping each photo's bottom. Under each: **name** (bold, primaryText, lineLimit 1),
  **team** (gray `Color(white: 0.5)`, lineLimit 1), **score** in **white bold** (`primaryText`,
  ~size 24; drop the current green glow). Tapping a podium player → `PlayerDetailView`.
- **Ranked list (rank 4…N — all returned players, no cap):** flat rows in the same card, each:
  rank number (left, gray/primary), circular avatar (~36), **name + team under it**, score
  (white bold, right). Subtle `Color(white: 0.15)` divider between rows. Tapping a row →
  `PlayerDetailView`.
- **Footer:** "Ver listado completo" centered, `accent`, ~size 14 semibold; tapping →
  `TopStatDetailView(tournament:stat:categoryName:)` where `stat = category.stats.first?.statName`.

Score formatting on this screen stays `tournament.usesAverage ? "%.1f" : "%.0f"`. Categories
with fewer than 3 players keep a graceful fallback (title + rows, no podium), as today.

## 4. Full-list screen (new `TopStatDetailView`)

Pushed from the footer. Inputs: `tournament`, `stat` (key), `categoryName` (display).

- On `.task`, calls `fetchTopStatDetail(for:stat:)`. Standard loading / error(retry) / empty states.
- **Fixed filter card at top** (matches image #19; dark rounded card, does not scroll with the list):
  - **Buscar:** label `"Buscar"` (primaryText, ~16 semibold) + `TextField("Nombre", text: $search)`
    styled with padding, `Color(white: 0.12)` fill, rounded stroke `Color(white: 0.3)`; filters
    live by `player.fullName.localizedCaseInsensitiveContains(search)`.
  - **Equipo:** label `"Equipo"` + a `Menu` styled as a rounded-bordered control showing the
    selected team (default `"Todos"`) + `chevron.down`. Options: `"Todos"` then the distinct
    `teamName`s of the returned players, sorted. Selecting filters to that team.
- **State:** `@State search = ""`, `@State selectedTeam = "Todos"`.
- **Filtered list:** `players.filter { (search.isEmpty || $0.player.fullName.localizedCaseInsensitiveContains(search)) && (selectedTeam == "Todos" || $0.teamName == selectedTeam) }`.
- **Rows:** scrolling list below the filter card — each: the player's own `rank` (from the API,
  not renumbered) + circular avatar + **name / team** + score. Score formatting uses the
  response's `average` flag (`average ? "%.1f" : "%.0f"`). Tapping a row → `PlayerDetailView`.
- Filtered-to-empty → small empty state ("No hay jugadores.").
- Player photo URL uses the existing inline pattern
  (`picture.hasPrefix("http") ? picture : "\(APIConfig.baseURL)/\(picture)"`); initials fallback.

## 5. Navigation & scope

- Podium players and list rows (both screens) push `PlayerDetailView(stat:tournamentId:)` — a
  `PlayerStatEntry` + tournament id, as today.
- Footer link pushes `TopStatDetailView`.
- **Scope:** `Stats.swift` (`rank`, `TopStatDetail`); `APIService.swift` (`fetchTopStatDetail`);
  `StatsLeadersView.swift` (restyle each page into the single card + footer link; keep carousel);
  new `TopStatDetailView.swift`. `PlayerDetailView` unchanged. Other tabs/views untouched.

## Out of scope

- No changes to `PlayerDetailView` itself.
- No caching/persistence of filter state across navigations.
- The main-screen carousel mechanics (TabView + dots) are preserved, only the page content is
  restyled.
