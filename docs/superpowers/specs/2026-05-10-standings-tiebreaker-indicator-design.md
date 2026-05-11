# Tiebreaker indicator in standings — design

**Date:** 2026-05-10
**Status:** Approved for implementation
**Scope:** iOS app (`Brackets`)

## Background

The web app shows a small info icon next to standings rows that are part of a tie group, and a tooltip on tap explaining how the tie was broken. The Rails API now returns a `tiebreaker` object on each standings record. The iOS app should match this behavior.

## API contract

`GET /api/tournaments/:id/standings.json` — each team object includes a new `tiebreaker` field.

`null` when the team is not part of a tie group. Non-null when it is:

```json
{
  "tiebreaker": {
    "group_index": 1,
    "bucket_id": 2,
    "bucket_size": 3,
    "reason": "fiba_score",
    "fiba_breakdown": [
      { "id": 8,  "name": "Lakers", "fiba_score": 7 },
      { "id": 12, "name": "Heat",   "fiba_score": 6 }
    ],
    "h2h_games": null,
    "mini_table": null
  }
}
```

- `reason` is one of `"fiba_score"`, `"h2h"`, `"mini_table"`.
- Exactly one of `fiba_breakdown` / `h2h_games` / `mini_table` is populated, matching `reason`.
- Teams sharing the same `(group_index, bucket_id)` are in the same tie group. Display does not need to cross-reference this — each row's `tiebreaker` is self-contained.
- The existing `tie_breaker: String` field (separate from this new one) is unused in views; it is being relaxed to optional for defensive decoding.

## User-facing behavior

### Row icon

- For each `TeamStanding` whose `tiebreaker != nil`, render a small `info.circle` SF Symbol in the standings row, between the team name area and the stats columns.
- Subtle gray (`AppTheme.Colors.secondaryText`), ~14pt glyph, 28×28 tap target.
- No icon when `tiebreaker == nil`.
- Icon presence does not shift the right-side numeric columns (it sits to the left of the stats `HStack`, after the `Spacer`).

### Tap behavior

- Tapping the **icon** opens a sheet with the tiebreaker breakdown.
- Tapping **anywhere else** on the row continues to navigate to `TeamDetailView` (existing behavior).
- For rows with no tiebreaker, behavior is unchanged.

### Sheet

- `.sheet(item:)` driven by an optional `Tiebreaker?` state on `StandingsView`.
- Detents: `[.medium]`. Drag indicator visible.
- Dark background; custom header (no system navigation bar) matching the app's other detail surfaces.
- Header: title `"Desempate"` in accent (lime) color, uppercase, tracked. Subtitle line below in secondary text, mapped from `reason`:
  - `fiba_score` → `"Resuelto por puntaje FIBA"`
  - `h2h` → `"Resuelto por enfrentamiento directo"`
  - `mini_table` → `"Resuelto por mini-tabla"`

### Sheet content per reason

**`fiba_score`** — two-column table sorted descending by `fiba_score` (API already orders):

| Equipo | FIBA |
|--------|------|
| Lakers |    7 |
| Heat   |    6 |

Team name left-aligned (`body`), score right-aligned (`bodyBold`). Hairline divider between rows.

**`h2h`** — one row per game from `h2h_games`:

```
Lakers   80  -  75   Heat
```

The winner side (name + score) uses `bodyBold` + accent (lime). The losing side uses `body` + `primaryText`. Names truncate with `lineLimit(1)`, `minimumScaleFactor(0.8)`. Hairline divider between games.

**`mini_table`** — four-column table in `mini_table` order (already sorted by rank):

| Equipo | F   | C   | Dif |
|--------|-----|-----|-----|
| Lakers | 240 | 220 | +20 |
| Heat   | 200 | 230 | -30 |

- `F` = favor, `C` = against, `Dif` = `favor - against`.
- Numeric columns are fixed-width (~44pt) for alignment.
- `Dif` color: positive → `AppTheme.Colors.positive`, negative → `AppTheme.Colors.negative`, zero → `AppTheme.Colors.neutral`. `+` prefix when positive.
- Hairline divider between rows.

### Empty/edge cases

If the array that matches `reason` is `nil` or empty (shouldn't happen per contract but guards against bad data), show a single subtle line in the body: `"Sin datos."`

## Implementation

### Models (`APIService.swift`)

Add:

```swift
struct Tiebreaker: Codable, Sendable, Equatable, Identifiable {
    enum Reason: String, Codable, Sendable {
        case fibaScore = "fiba_score"
        case h2h
        case miniTable = "mini_table"
    }

    let groupIndex: Int?
    let bucketId: Int
    let bucketSize: Int
    let reason: Reason
    let fibaBreakdown: [FibaEntry]?
    let h2hGames: [H2HGame]?
    let miniTable: [MiniTableEntry]?

    var id: String { "\(groupIndex ?? 0)-\(bucketId)" }

    enum CodingKeys: String, CodingKey {
        case groupIndex   = "group_index"
        case bucketId     = "bucket_id"
        case bucketSize   = "bucket_size"
        case reason
        case fibaBreakdown = "fiba_breakdown"
        case h2hGames      = "h2h_games"
        case miniTable     = "mini_table"
    }
}

struct FibaEntry: Codable, Sendable, Equatable, Identifiable {
    let id: Int
    let name: String
    let fibaScore: Int
    enum CodingKeys: String, CodingKey {
        case id, name
        case fibaScore = "fiba_score"
    }
}

struct H2HGame: Codable, Sendable, Equatable, Identifiable {
    let teamA: H2HSide
    let teamB: H2HSide
    var id: String { "\(teamA.id)-\(teamB.id)-\(teamA.score)-\(teamB.score)" }
    enum CodingKeys: String, CodingKey {
        case teamA = "team_a"
        case teamB = "team_b"
    }
}

struct H2HSide: Codable, Sendable, Equatable {
    let id: Int
    let name: String
    let score: Int
    let winner: Bool
}

struct MiniTableEntry: Codable, Sendable, Equatable, Identifiable {
    let id: Int
    let name: String
    let favor: Int
    let against: Int
    var diff: Int { favor - against }
}
```

Modify `TeamStanding`:

```swift
let tieBreaker: String?         // was: let tieBreaker: String — relaxed to optional
let tiebreaker: Tiebreaker?     // new
```

`CodingKeys` adds `case tiebreaker`. Existing `case tieBreaker = "tie_breaker"` stays. Both fields decode with `decodeIfPresent`.

### Views

**`StandingsView.swift` — `StandingCard`:**

- New parameter: `let onTiebreakerTap: (() -> Void)?` (defaults to `nil`).
- Inside the row `HStack`, after the existing `Spacer(minLength: AppTheme.Spacing.small)` and before the stats `HStack`, insert:

```swift
if standing.tiebreaker != nil, let onTap = onTiebreakerTap {
    Button(action: onTap) {
        Image(systemName: "info.circle")
            .font(.system(size: 14, weight: .regular))
            .foregroundStyle(AppTheme.Colors.secondaryText)
            .frame(width: 28, height: 28)
            .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .padding(.trailing, 6)
}
```

**`StandingsView.swift` — `standingsList`:**

- Add `@State private var presentedTiebreaker: Tiebreaker?` on `StandingsView`.
- Change each row from `NavigationLink { ... } label: { StandingCard }` to a `ZStack` that overlays an invisible `NavigationLink` behind a tappable `StandingCard`:

```swift
ZStack {
    NavigationLink {
        TeamDetailView(
            standing: standing,
            tournamentId: tournament.id,
            tournamentName: tournament.name,
            rank: index + 1
        )
    } label: { EmptyView() }
    .opacity(0)

    StandingCard(
        position: index + 1,
        standing: standing,
        usesAverage: tournament.usesAverage,
        onTiebreakerTap: { presentedTiebreaker = standing.tiebreaker }
    )
}
```

This keeps row-tap navigation working while letting the icon button intercept its own taps. The icon is rendered inside `StandingCard` and sits visually above the invisible link.

- On the outer `ScrollView` (or the root `ZStack`), attach:

```swift
.sheet(item: $presentedTiebreaker) { tb in
    TiebreakerSheet(tiebreaker: tb)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
}
```

### New file: `TiebreakerSheet.swift`

Single SwiftUI view in a new file. Top-level structure:

```swift
struct TiebreakerSheet: View {
    let tiebreaker: Tiebreaker

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                    header
                    switch tiebreaker.reason {
                    case .fibaScore: FibaScoreTable(entries: tiebreaker.fibaBreakdown ?? [])
                    case .h2h:       H2HList(games: tiebreaker.h2hGames ?? [])
                    case .miniTable: MiniTable(entries: tiebreaker.miniTable ?? [])
                    }
                }
                .padding(.horizontal, AppTheme.Layout.screenPadding)
                .padding(.top, AppTheme.Spacing.large)
                .padding(.bottom, AppTheme.Layout.large)
            }
        }
    }

    private var header: some View { /* title + subtitle */ }
}
```

Three private subviews `FibaScoreTable`, `H2HList`, `MiniTable` render the three reason-specific layouts described above. Each handles its own empty state (`"Sin datos."`).

## Acceptance

- Teams without `tiebreaker` show no icon and behave identically to before.
- Teams with `tiebreaker` show an `info.circle` icon between the team name area and the stats columns.
- Tapping the icon opens a `.medium` sheet titled `"Desempate"` with reason-specific content.
- Tapping anywhere else on the row navigates to `TeamDetailView` as before.
- Right-aligned stat columns and the record badge remain visually aligned across all rows in a tournament.
- All three `reason` values render correctly with example payloads from staging.
- Works identically inside grouped standings (`StandingsResult.groups`).

## Out of scope

- No changes to web/Rails. iOS consumes data as provided.
- No analytics events for icon tap.
- No animations beyond the default sheet transition.
- The legacy `tie_breaker: String` field is preserved (relaxed to optional) but still not consumed by any view.
