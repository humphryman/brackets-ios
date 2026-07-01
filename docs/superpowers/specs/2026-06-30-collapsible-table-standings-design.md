# Collapsible Table Standings — Design

**Date:** 2026-06-30
**File touched:** `Brackets/StandingsView.swift` (view-only; no model or API changes)

## Goal

Redesign the grouped standings view so each group renders as a single card containing a
compact table (column-header row + tight team rows), matching the provided mockup. Group
card headers are collapsible. On first load the first group is expanded and the rest are
collapsed.

## Data mapping (existing `TeamStanding` fields — no API change)

| Column | Source |
|--------|--------|
| `#`    | row position (index + 1) |
| `EQUIPOS` | `teamName` (as-is casing to match the mockup, truncates; existing tiebreaker `info.circle` icon when `tiebreaker != nil`) |
| `J`    | `total` |
| `G`    | `wins` |
| `P`    | `losses` |
| `FAV`  | `pointsFor` |
| `CON`  | `pointsAgainst` |
| last   | `AVG` (green pill) when `tournament.usesAverage`, else `DIF` (signed, +/- colored) |

Ties (`tie`) are not displayed. The old win-loss `RecordBadge` is dropped from this view —
`G`/`P` express the record now.

## Layout

### Group card (grouped case)
A single rounded card per group (`AppTheme.Colors.cardBackground` on the darker screen
background). Contents:

1. **Header row (tappable):** `group.name.capitalized` (bold white) on the left; a chevron
   on the right (`chevron.right` rotated 90° when expanded, i.e. ▶ → ▼). Tapping anywhere on
   the header toggles the group's expansion via `withAnimation(.spring(response: 0.3,
   dampingFraction: 0.8))`.
2. **Column header row** (rendered only when expanded): `#  EQUIPOS  J  G  P  FAV  CON  AVG`
   in `AppTheme.Typography.tinyCaption`, `secondaryText`, uppercase.
3. **Team rows** (rendered only when expanded): each row is a `NavigationLink` →
   `TeamDetailView(standing:tournamentId:tournamentName:rank:)` with the same arguments used
   today (`rank = index + 1`). `.buttonStyle(.plain)`. A thin divider separates rows.

### Flat (ungrouped) case
Render the same column-header row + team rows inside a single card, but with **no** header
bar and **no** collapse — always visible.

## Column alignment

A shared `StandingsColumns` enum/struct holds fixed widths so the header row and every team
row line up:
- `#` — narrow fixed width (e.g. 20)
- `EQUIPOS` — flexible (`Spacer`/`frame(maxWidth:.infinity, alignment:.leading)`), truncates
- `J`, `G`, `P` — narrow numeric (e.g. 22 each)
- `FAV`, `CON` — wider numeric (e.g. 34 each)
- last column — AVG/DIF (e.g. 46)

All numeric columns are right/center aligned consistently between header and rows.

## AVG / DIF cell

- **AVG** (`usesAverage == true`): value formatted `String(format: "%.3f", value)` — unsigned,
  three decimals, matching the mockup (e.g. `1.124`). No `+`/`-` prefix (unlike the current
  `AvgColumn`). Rendered as accent-green text on a subtle green-tinted pill (flat accent green
  for all rows, no intensity scaling). Nil → `-`.
- **DIF** (`usesAverage == false`): signed value, colored `positive`/`negative`/`neutral`
  (reuse current `DiffColumn` coloring). No pill.

## Collapse state

`StandingsView` gains `@State private var expandedGroups: Set<String>` keyed by `group.id`
(which is `name`). On the first successful load with groups, initialize to `{ firstGroup.id }`
(first expanded, rest collapsed). Guard initialization so it only runs once (e.g. a
`@State private var didInitExpansion` flag), so a manual collapse of the first group is not
undone by a refresh. Toggling a header inserts/removes the id inside `withAnimation`.

## Components (all in `StandingsView.swift`)

- `StandingsColumns` — width constants + small helpers for numeric cells.
- `StandingsTableHeader` — the `# EQUIPOS J G P FAV CON AVG` row (takes `usesAverage`).
- `StandingsTableRow` — one team `NavigationLink` row (position, name + tiebreaker icon,
  numeric cells, AVG/DIF cell). Takes `standing`, `position`, `usesAverage`, `onTiebreakerTap`.
- `GroupStandingsCard` — collapsible wrapper: header + chevron + (when expanded) header row +
  rows. Takes `group`, `isExpanded: Bool`, `onToggleHeader: () -> Void`, plus the row closures.
- `AvgPill` / adapted `AvgColumn` and `DiffColumn` for the last cell.

`StandingCard` (the old per-team card) and its `RecordBadge` usage are removed from this view.

## Unchanged

Champion sub-tab + `StandingsSubTabBar` + `ChampionPanel`/`PodiumCard`; loading / error /
empty states; the tiebreaker `.sheet` and `presentedTiebreaker` flow; `TeamDetailView`
navigation target and arguments.

## Out of scope

- No API / model changes.
- No changes to the flat-vs-grouped decoding logic in `StandingsResult`.
- No persistence of collapse state across app launches (in-memory only).
