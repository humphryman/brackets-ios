# Bracket Morph Navigation (Apple Sports–style)

**Date:** 2026-07-16
**Status:** Approved design, ready for implementation plan

## Summary

Replace the bracket tab's horizontal-paging navigation with an Apple Sports–style
**windowed, morphing** navigation:

- A top **stage selector** shows only the stages that apply to the tournament
  (Spanish abbreviations), with a draggable 2-wide highlight marking the two
  stages currently visible.
- The content shows exactly **two adjacent stages at a time**.
- You change the visible pair by **dragging the selector** or **swiping the
  content horizontally** — both drive the same state.
- As you move toward a later stage, the round that becomes the **left column
  condenses** (packs vertically) while the right column sits at bracket-tree
  midpoints. The change is a **per-card morph** that tracks the drag
  interactively, not a page slide.

No changes to card, team-row, avatar, connector, or live-badge **styling**, or to
data loading / live refresh. This is a navigation + column-layout change only.

## Non-goals

- Do not restyle matchup cards, team rows, avatars, connectors, or the live badge.
- Do not show a Group Stage (GS) entry — bracket rounds are knockout-only, so GS
  never appears anyway.
- Keep the existing multi-bracket `ChipCarousel` (Gold/Silver/Bronze) above the
  new stage selector.

## The layout engine

### The core idea

Today `matchupSpacing(for:)` / `topPadding(for:)` are functions of the **absolute**
round index: round 0 is tight, each later round's gap doubles, and the whole tree
is laid out once and slid horizontally. That is exactly why a round never
re-condenses when it becomes the left column.

Change spacing to a function of each round's **distance from the window's left
edge**:

```
d = roundIndex - windowProgress
```

where `windowProgress` is a single continuous, animatable value in
`0 … (rounds.count - 2)`. Both horizontal position and vertical spacing become
continuous functions of `windowProgress`, so animating it produces an automatic
per-card morph — no `matchedGeometryEffect`, no separate pages.

### Formulas

Existing constants (unchanged): `matchupCardWidth = 180`, `matchupCardHeight = 153`
(referred to as `cardH`), `connectorWidth = 36`,
`columnWidth = matchupCardWidth + connectorWidth = 216`.

Base (condensed) spacing, unchanged from today:
```
baseSpacing = (activeType == "semifinals") ? 80 : 24
step0 = cardH + baseSpacing
```

Clamp the layout distance so only the visible window morphs and off-window columns
keep a stable end-state layout (and never produce negative/huge spacing):
```
dc(r) = min(max(roundIndex - windowProgress, 0), 1)
```

Per-round vertical layout:
```
spacing(dc) = (baseSpacing + cardH) * pow(2, dc) - cardH
topPad(dc)  = step0 * (pow(2, dc) - 1) / 2
step(dc)    = cardH + spacing(dc)
```

- At `dc = 0` (left column): `spacing = baseSpacing` (condensed), `topPad = 0`.
- At `dc = 1` (right column): `spacing = 2·baseSpacing + cardH` (tree-spread),
  `topPad = step0/2` (cards centered between their two source cards).

These are the continuous generalization of the existing recursion
(`spacing(r) = spacing(r-1)*2 + cardH`, `topPadding(r) = topPadding(r-1) +
step(r-1)/2`), so connector/card alignment is preserved.

Horizontal position: the rounds are still an `HStack` of `roundColumn`s (each
`columnWidth` wide); offset the whole stack by:
```
xOffset = -windowProgress * columnWidth + AppTheme.Layout.screenPadding
```
so round `r` sits at `(r - windowProgress) * columnWidth`; the window shows
`dc ∈ [0,1]`. Columns with `d < 0` (exiting left) or `d > 1` (entering right) are
horizontally off-screen and clipped.

### Why the morph "just works"

As `windowProgress` animates 0→1, the shared middle round's `d` passes 1→0, so its
`spacing`/`topPad` interpolate from spread to condensed — its cards move vertically
into a packed column while the stack slides horizontally. The exiting round
(`d`→negative, clamped to 0) stays condensed as it leaves; the entering round
(`d`→1, clamped to 1) stays spread as it arrives. Only the middle round morphs —
exactly the requested behavior. Because doubling spacing halves the card count,
every column's total height is ≈ equal, so vertical scrolling stays stable.

### Connectors

Connectors are computed from the left round's spacing (`connectorsColumn` /
`connectorPair` already take `spacing`); pass `spacing(dc)` for that round so
connectors morph continuously with the cards. No connector **style** change.

## Gestures & state

Replace `currentPage: Int` and `dragOffset: CGFloat` with:
```
@State private var windowProgress: CGFloat = 0
@State private var gestureStartProgress: CGFloat? = nil
```

`maxWindow = max(0, rounds.count - 2)`.

Content horizontal drag (keep the existing axis-detecting `simultaneousGesture`
approach so vertical scroll is never blocked — this preserves the prior
scroll-vs-paging fix):
- `onChanged`: if the drag is horizontally dominant
  (`abs(width) > abs(height)`), set `gestureStartProgress` on first change, then
  `windowProgress = clamp(gestureStartProgress - value.translation.width / columnWidth, 0, maxWindow)`.
  The morph tracks the finger.
- `onEnded`: spring-animate `windowProgress` to `snappedTarget`, then reset
  `gestureStartProgress = nil`. `snappedTarget`: if
  `abs(predictedEndTranslation.width) > columnWidth/3` move one step in the drag
  direction (flick), else `round(windowProgress)`; clamp to `[0, maxWindow]`.

Selecting a different bracket in the `ChipCarousel` resets `windowProgress = 0`.

## Stage selector (clean adaptation, Spanish)

New `StageSelector` view (in `BracketView.swift`), replacing the old
`bracketHeaders` capsule row.

- Inputs: `labels: [String]`, `windowProgress: Binding<CGFloat>`, `maxWindow: CGFloat`.
- Layout (via `GeometryReader` for `totalWidth`, `segmentWidth = totalWidth / labels.count`):
  - A row of stage labels, one per segment, centered. The two segments under the
    highlight render in `AppTheme.Colors.primaryText`; the rest dimmed
    (`Color(white: 0.45)`).
  - A rounded track behind the labels (`Color(white: 0.10)`).
  - A 2-wide highlight: `x = windowProgress * segmentWidth`, `width = 2 * segmentWidth`,
    a rounded rect with a lime border (`AppTheme.Colors.accent`) over a subtly
    lighter fill — matching the app's selected-chip language.
  - ‹ › chevrons at the highlight's inner edges; tapping steps
    `windowProgress` by ∓1 (spring-animated, clamped). Chevrons are hidden/disabled
    at the ends (and entirely when `maxWindow == 0`).
- Drag on the highlight updates `windowProgress` by
  `translation.width / segmentWidth` (clamped), mirroring the content drag; release
  snaps to the nearest integer.

Label mapping from the round names produced by `buildRounds()`:

| round.name           | label   |
|----------------------|---------|
| `16vos de Final`     | `16vos` |
| `Octavos de Final`   | `8vos`  |
| `Cuartos de Final`   | `4tos`  |
| `Semifinal`          | `Semis` |
| `Final`              | `Final` |

(A helper maps by exact round name; unknown names fall back to the round name.)

## Reuse / replace

**Unchanged:** `matchupCard`, `teamRow`, `teamAvatar`, `venueRow`, `matchupTimeLine`,
`connectorPair` visuals, `BracketLiveBadge`, the last-column inline `Final` / `3er
Lugar` labels, third-place handling, `buildRounds` and all slot/propagation logic,
`loadGames`, live refresh, and the multi-bracket `ChipCarousel`.

**Replaced:**
- `bracketHeaders` (top capsule header row) → `StageSelector`.
- `bracketPager` / `staticBracket` / `pagedBracket` integer paging → a single
  `bracketContent` that renders the offset `HStack` of `roundColumn`s inside the
  existing vertical `ScrollView`, driven by `windowProgress`.
- `matchupSpacing(for: roundIndex)` / `topPadding(for: roundIndex)` → `spacing(dc)`
  / `topPad(dc)` taking the clamped continuous distance; `roundColumn` /
  `connectorsColumn` take the round's `dc` instead of `roundIndex`.
- State: `currentPage` / `dragOffset` → `windowProgress` / `gestureStartProgress`.

## Edge cases

- **2-stage bracket** (semifinals type → `[Semifinal, Final]`): `maxWindow = 0`,
  `windowProgress` fixed at 0, selector shows two fixed stages, chevrons disabled,
  content drag clamped (no-op). `buildRounds` always appends SF + Final, so there
  are always ≥ 2 rounds.
- **Off-window columns**: horizontally clipped; `dc` clamp keeps their vertical
  layout bounded so content height and scroll stay stable.
- **Final + Tercer Lugar**: the last window's right column stacks Final over 3er
  Lugar exactly as today.
- **Live badge / navigation links** on cards behave as today.

## Files

- **Modify:** `Brackets/BracketView.swift` — the whole navigation/layout section
  (state, gestures, `spacing`/`topPad`, content assembly), plus the new
  `StageSelector` view and a round-name→label helper. Models, card views,
  connectors, data, and live refresh are untouched.

No new files; no `project.pbxproj` change.

## Verification

No unit-test target; verification is Xcode build + previews + manual:

1. `⌘B` builds (`Brackets` scheme).
2. Previews (or a live run) for each bracket type:
   - `dieciseisavos` (R32): 5 stages `16vos·8vos·4tos·Semis·Final`, 4 windows.
   - `octavos` (R16): 4 stages, 3 windows.
   - `quarterfinals` (QF): 3 stages, 2 windows.
   - `semifinals`: 2 stages, 1 fixed window (no paging).
3. Manual:
   - Dragging content and the selector both move the window and stay in sync.
   - The left column condenses / right column spreads as the window advances, with
     cards morphing (tracking the drag), not sliding as a page.
   - Vertical scrolling still works within a window (not blocked by the horizontal
     gesture).
   - Connectors stay attached to card centers throughout the morph.
   - Final + 3er Lugar render in the last window; live badges and card taps work.
