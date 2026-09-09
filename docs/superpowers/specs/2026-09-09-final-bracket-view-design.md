# Final Bracket View — Design Spec

**Date:** 2026-09-09
**Status:** Approved for implementation planning
**Area:** `Brackets/BracketView.swift` and new `Brackets/Final/` module

## 1. Purpose

Introduce a distinct, richly animated view for the `final` bracket type. When
a bracket's `type == "final"`, the app replaces the horizontal morphing bracket
with a full-screen vertical layout centered on the Final match (and, when it
exists, the Tercer Lugar match). Every other bracket type
(`quarterfinals`, `octavos`, `dieciseisavos`, etc.) is left completely
untouched.

The card background is a four-layer animated composition whose colors are
derived from each team's logo. The visual spec is defined by the web prototype
and is reproduced in full in section 6.

## 2. Scope & non-goals

**In scope**
- A new `FinalBracketView` rendered only for `type == "final"`.
- A `FinalMatchCard` with two size variants (prominent, compact).
- A four-layer animated `FinalCardBackground` (base, static split, three
  screen-blended moving blobs, scrim) with reduced-motion and off-screen
  handling.
- Client-side, cached extraction of a dominant color per team logo, with the
  prototype's filter → bucket → lift → separate → fallback rules.
- Support for all game states: upcoming/scheduled, live, and finished (scores +
  winner emphasis + live badge).
- Tap-through to existing game detail screens when a real game backs the card.

**Non-goals**
- No changes to any other bracket type's rendering.
- No backend/API change. Colors are extracted on-device (structured so a future
  API-provided hex could replace extraction, but that migration is not built
  now).
- No Android/Compose implementation (this repo is iOS; the prototype's Compose
  notes are reference only).

## 3. Data & integration

### 3.1 Branch point
`BracketView` already computes `activeType` (the selected bracket's lowercased
`type`, falling back to `tournament.bracketType`). In the view body, branch:

- `activeType == "final"` → render `FinalBracketView` and **hide** the
  `StageSelector` and the horizontal morphing bracket entirely.
- otherwise → existing behavior, unchanged.

The top bracket segmented picker (shown when `brackets.count >= 2`) is
unaffected; only the content area below it swaps.

### 3.2 Matchup construction
Reuse the existing `buildMatchup(stage:slot:propagation:)` on `BracketView`,
which already folds a real game (via `gameForSlot`) *or* a placeholder (via
`placeholderForSlot`) into a single `BracketMatchup`. For the final type:

- `finalMatchup  = buildMatchup(stage: "Final",        slot: 1, propagation: nil)`
- `thirdMatchup  = buildMatchup(stage: "Tercer Lugar", slot: 1, propagation: nil)`

Propagation is `nil` because the final bracket carries its own Final and Tercer
Lugar placeholders directly (no Semifinal column is shown for this type).

These two matchups (plus the `tournament`) are passed into `FinalBracketView`.
The stage-matching helpers already treat `"Final"` as an exact match and handle
`"Tercer Lugar"` as a single-slot stage.

### 3.3 "Has info" rule
A matchup **has info** when any of the following is true:
- it is backed by a real game (`hasGame == true`), or
- its placeholder contributed any non-null field — represented on the built
  `BracketMatchup` as a non-nil `homePlaceholder`, `awayPlaceholder`,
  `scheduledTime`, or `venue`.

A matchup with none of these has **no info**.

## 4. Layout decision

Computed in `FinalBracketView`:

- **Third place has info** → **compact two-card** layout: a vertical stack with
  the Final card (stage label "FINAL") on top and the Tercer Lugar card (stage
  label "TERCER LUGAR") below. Scrollable if it overflows.
- **Third place has no info** → single **prominent** Final card filling the
  available height. This includes the case where the Final itself has no info,
  which renders as a prominent TBD-vs-TBD card.

The Final card is always shown. The Tercer Lugar card is shown only when the
third-place matchup has info.

## 5. Components

New files live under `Brackets/Final/`.

### 5.1 `FinalBracketView`
- Inputs: `finalMatchup: BracketMatchup`, `thirdMatchup: BracketMatchup`,
  `tournament: Tournament`.
- Decides compact vs prominent layout per section 4.
- Resolves each card's color pair via `TeamColorStore` (section 7).
- Owns the scroll container and vertical spacing.

### 5.2 `FinalMatchCard`
One card for a single matchup. Size variant enum: `.prominent`, `.compact`.

Content, top → bottom:
1. **Stage pill** — stroked capsule, uppercase, condensed/semibold ("FINAL" /
   "TERCER LUGAR").
2. **Crest row** — chip A · "VS" · chip B, each team's name below in condensed
   uppercase.
   - Crest chip: `AsyncImage` in a `Circle` with a 1px gray-700 outline.
   - No logo → **initial chip**: gray-700 fill, first letter of the team name in
     the condensed heading face at ~46% of the chip diameter, same footprint as
     a crest.
3. **Result region**:
   - Upcoming/scheduled → date line (e.g. "13 AGOSTO, 2026") + big time
     ("7:00 PM").
   - Finished → scores with winner emphasized (accent) and loser dimmed; date
     retained smaller.
   - Live → live badge + current score + period.
4. **Countdown pill** — "FALTAN X DÍAS" (see 5.4). Prominent variant only, and
   only for a future, not-yet-played game.
5. **Divider + venue footer** — mappin + venue name; Google Maps link when
   coordinates exist (reuse the existing venue-row pattern).

Sizes: `.prominent` uses a large crest (~130–150pt) and large time (~56–64pt);
`.compact` uses a smaller crest (~64–100pt) and smaller time (~32–36pt) and
omits the countdown pill.

**Tap behavior:** if the matchup is backed by a real game, the whole card is a
`NavigationLink` routing to `LiveGameDetailView` / `GameResultView` /
`UpcomingGameView` exactly as the existing bracket cards do. Placeholder-only
cards are not tappable.

### 5.3 `FinalCardBackground`
The four-layer animated background (section 6). Inputs: resolved `colorA`,
`colorB`, and an `animate` gate.

### 5.4 Countdown formatter (pure function)
Given the matchup's `scheduledTime` in `AppConfig.DateTime.apiTimeZone`:
- game finished or live, or time in the past → no pill.
- same calendar day → "HOY".
- next calendar day → "MAÑANA".
- otherwise → "FALTAN N DÍAS" where N is whole calendar days until the game.

## 6. Four-layer animated background

Bottom → top, all clipped to a single 16pt rounded rectangle (clip the whole
stack, not each layer):

1. **Dark base** — a near-black radial gradient. Everything above is additive
   light; this must stay dark.
2. **Static split** — one ~100° diagonal linear gradient: `colorA` at 26% alpha
   on the leading edge, transparent through the middle, `colorB` at 26% alpha on
   the trailing edge. Never animates. Guarantees each side reads as its team.
3. **Three moving blobs** — blurred radial gradients composited with
   `.blendMode(.screen)`:
   - Blob A anchored off the left edge (`colorA`).
   - Blob B anchored off the right edge (`colorB`).
   - A center blob (blend of A and B) that pulses.
   - Per-blob animation:
     - size 330×400 pt, blur radius 44,
     - travel range ±95 pt x, ±120 pt y,
     - scale 1.0 → 1.35,
     - opacity 0.5 → 1.0,
     - loop durations 7s (base), 9.45s (×1.35), 4.9s (×0.7) — never equal, or
       they visually sync,
     - `easeInOut`, `repeatForever(autoreverses: true)`.
   - The base + static split + blob group are wrapped in `.compositingGroup()`
     so `screen` blends additively against what's below instead of muddying.
4. **Scrim** — a dark vertical gradient plus a vignette, over the color but under
   the text. Keeps text legible regardless of blob position.

**Reduced motion:** when `@Environment(\.accessibilityReduceMotion)` is true,
render layers 1, 2, and 4 only and skip the blobs entirely. The result still
reads as the brand.

**Off-screen / backgrounded:** the infinite animation must not run when the card
is not visible. Gate `animate` on `.onAppear`/`.onDisappear` and
`scenePhase == .active`. Do not start the animation from `init`.

**Contrast:** verify the worst frame (brightest blob directly under the text) at
≥4.5:1. The scrim is what makes this hold; it must not be dropped.

## 7. Color pipeline

Two colors drive a card, both derived from the crests. Extraction runs once per
team and is cached; it is never run per render.

### 7.1 `HSLColor` + `TeamColorExtractor` (pure)
`extractDominant(_ image: UIImage) -> HSLColor?`:
1. Downscale to ~48×48 via CoreGraphics (dominant hue, not detail).
2. Reject pixels that cannot be a team color: alpha < 200; lightness < 12% or
   > 92%; saturation < 25%.
3. Bucket survivors by rounding each RGB channel down to a multiple of 16; count;
   the fullest bucket wins.
4. **Lift** the winner into the usable band: saturation ≥ 0.55, lightness clamped
   into 0.42–0.62.
5. Return `nil` if nothing survives the filters.

### 7.2 `TeamColorStore` (`@MainActor`, `@Observable`, shared singleton)
`color(forTeamId:logoURL:) async -> HSLColor?`:
- Memoized by team id for the process lifetime.
- On first request, downloads the logo via `URLSession.shared`, decodes a
  `UIImage`, and runs `extractDominant`.
- Concurrent requests for the same team coalesce onto one in-flight task.

### 7.3 Pair resolution (pure), `resolveFinalPair(a:b:) -> (Color, Color)`
Fallback pair, in order: `#6b7280` (neutral gray), then `#1a2e05`
(lime-950).

- **Both present** — if the two hues are within 25°, rotate B by +40° (or drop it
  to the neutral) so the two sides stay distinct. Otherwise use both as-is.
- **One missing** — the missing side takes fallback[0] `#6b7280`; the present
  side keeps its sampled + lifted color.
- **Both missing** — fallback[0] `#6b7280` and fallback[1] `#1a2e05`. Never the
  same color on both sides.

The fallback values are used as-is; the lift step (7.1 step 4) is **not** applied
to them (they are chosen palette values, and lifting lime-950 would push it out
of palette).

### 7.4 Render-time behavior
While extraction is in flight, the card renders with the resolved fallback pair,
then crossfades to the resolved colors when they arrive — no gray→brand pop.

## 8. Theme additions

Add `lime950` (`#1a2e05`) to `AppTheme.Colors` (sibling of the existing
`lime900 = #365314` and `lime400`). All other palette values already exist.

## 9. Files touched

New (`Brackets/Final/`):
- `FinalBracketView.swift`
- `FinalMatchCard.swift`
- `FinalCardBackground.swift`
- `TeamColorExtractor.swift` (includes `HSLColor`)
- `TeamColorStore.swift`

Edited:
- `BracketView.swift` — branch to `FinalBracketView` for `activeType == "final"`;
  expose the two built matchups.
- `AppTheme.swift` — add `lime950`.

## 10. Testing

The project has no test target and builds are Xcode-only, so the strategy is to
keep the decision logic in pure functions with no SwiftUI/UIKit view
dependencies, then cover them with unit tests:

- `extractDominant` — dominant color from synthesized swatch images (a mostly
  black crest with an orange region resolves to a lifted orange; an all-gray
  image resolves to `nil`).
- `resolveFinalPair` — near-identical hues get separated; one-missing takes
  fallback[0] and keeps the other sampled; both-missing yields the two distinct
  fallbacks and never gray twice.
- countdown formatter — HOY / MAÑANA / "FALTAN N DÍAS" / no-pill boundaries in
  `America/Tijuana`.

A lightweight `BracketsTests` target is added for these (run with ⌘U). If a test
target is undesirable, the same functions are instead exercised through a debug
`#Preview` harness.

## 11. Open risks

- **`blendMode(.screen)` + `compositingGroup()`** interaction with `.blur` must be
  verified on-device; the compositing group is required for the screen blend to
  compose against the layers below.
- **Animation lifecycle**: confirm the infinite transition fully stops when the
  card scrolls off-screen and when the app is backgrounded (no lingering
  60fps loop).
- **Extraction cost**: first paint of a card may show the fallback pair briefly
  before the crossfade; acceptable per section 7.4.
