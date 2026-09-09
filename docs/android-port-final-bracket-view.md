# Android Port — Animated Final Bracket View

A self-contained implementation prompt for porting the iOS **Final bracket view**
to the Android app (Jetpack Compose). iOS point sizes map 1:1 to Android `dp`/`sp`.

**Assumptions (confirmed):** the Android app already renders brackets and has the
same models/structure iOS had *before* this feature — i.e. it parses
`games.json` including the `brackets` array with `game_placeholders`, has
`Game`/`Team`/`Venue`/placeholder equivalents, a bracket screen that routes by
bracket `type`, and a `buildMatchup(stage, slot)`-style helper that folds a real
game *or* a placeholder into one matchup object. This prompt only adds the
`"final"`-type branch and everything it needs. Reuse your existing models; do not
re-parse the API.

**Design source of truth:** iOS spec `docs/superpowers/specs/2026-09-09-final-bracket-view-design.md`
plus the refinements below (this doc reflects the final shipped iOS look, which
supersedes the original spec in a few places — notably: **no countdown pill**,
**design-system gray badges** for the stage label, **system font** for the venue,
and a **dense** two-card mode).

---

## 0. Tokens & fonts

- **Accent lime:** `#C7F24A` in design docs / `#A3FF12` in code — use whatever your
  app already defines as the accent.
- **gray700** = `#252525` (team-chip fill + crest outline).
- **lime-950** = `#1A2E05` (second crestless fallback color). Add to your theme if
  absent.
- **Neutral gray fallback** = `#6B7280` (first crestless fallback color).
- **Brand face:** **Barlow Condensed** (bundled, SIL OFL), weights
  Regular/Medium/SemiBold/Bold/ExtraBold. Used for everything on the card EXCEPT
  the venue.
- **Venue face:** the **platform system font** (Roboto / system default) — the
  venue row deliberately does *not* use Barlow Condensed.
- **Dates:** locale `es_MX` (`Locale("es","MX")`), time zone `America/Tijuana`.
  Strip the API date's timezone offset before parsing, same as the rest of the app
  (never assume UTC).

---

## 1. Where it plugs in

In your bracket screen's content, add a branch: **when the selected bracket's
`type == "final"`** (lowercased), render the new `FinalBracketScreen` and hide the
horizontal/stage bracket UI entirely. Every other bracket type is untouched.

Placement matters: put the branch **after** your existing empty-state guard (the
"no games and no placeholders" case) and before the generic bracket rendering. A
final bracket that has a real game *or* any placeholder reaches the new screen; a
genuinely empty one still shows the empty state.

Build the two matchups with your existing helper:

```
finalMatchup = buildMatchup(stage = "Final",        slot = 1)   // always shown
thirdMatchup = buildMatchup(stage = "Tercer Lugar", slot = 1)   // shown only if it has info
```

`"Final"` and `"Tercer Lugar"` are single-slot stages (match the same way your
`gameForSlot` already special-cases them). No winner-propagation is needed for the
final type — the placeholders carry the team names directly.

---

## 2. Layout decision (`FinalBracketScreen`)

Inputs: `finalMatchup`, `thirdMatchup`, the tournament.

**Has-info rule** (identical to iOS):

```
fun hasInfo(m) = m.hasGame
              || m.homePlaceholder != null
              || m.awayPlaceholder != null
              || m.scheduledTime   != null
              || m.venue           != null
```

- **`hasInfo(thirdMatchup)` is true** → two-card layout, vertically stacked in a
  scrollable column, spacing **16.dp**, horizontal padding **12.dp**
  (your screen padding), bottom padding **24.dp**:
  - Final card: size **Prominent**, `dense = true`
  - Tercer Lugar card: size **Compact**, `dense = true`
- **otherwise** → a single **Prominent** Final card, `dense = false`, **top-aligned**
  (put it at the top of a Column with a flexible spacer below so black space sits
  beneath it — the card is content-sized, it must not stretch to fill the screen),
  horizontal padding **12.dp**, bottom padding **24.dp**.

The Final card is always shown (TBD-vs-TBD when it has no info). The Tercer Lugar
card appears only when it has info.

---

## 3. The card (`FinalMatchCard`)

Two sizes (`Prominent`, `Compact`) and a `dense: Boolean` flag. `dense` is true
only in the two-card layout; it tightens the vertical rhythm and shrinks the two
height-dominating elements so both cards fit on one screen.

### 3.1 Metrics table (sp / dp)

| Element | Prominent | Compact | Notes |
|---|---|---|---|
| Crest diameter | `dense ? 74 : 88` | `dense ? 60 : 72` | dp |
| Time size | `dense ? 46 : 58` | `dense ? 28 : 34` | sp |
| Date size | 15 | 12 | sp |
| Name size | 15 | 13 | sp |
| "VS" size | 18 | 15 | sp |
| Venue size | 15 | 13 | sp (system font) |
| "SIN AGENDAR" size | 34 | 22 | sp |
| Card vertical padding | `dense ? 18 : 26` | `dense ? 14 : 16` | dp |
| Card horizontal padding | 18 | 18 | dp |

Vertical gaps between sections (a fixed-height spacer, top → bottom):

| Gap | Prominent | Compact |
|---|---|---|
| stage pill → crest row | `dense ? 26 : 50` | `dense ? 16 : 26` |
| crest row → result region | `dense ? 22 : 46` | `dense ? 14 : 22` |
| result region → divider | `dense ? 26 : 58` | `dense ? 16 : 30` |
| divider → venue | `dense ? 12 : 14` | `dense ? 12 : 14` |

Card corner radius **16.dp**; **1.dp** border at `white @ 12%`
(`RoundedCornerShape(16.dp)` stroke). Card fill is the animated background from §4.

### 3.2 Content, top → bottom

1. **Stage pill** — use your **design-system gray Badge** component (the same one
   used on the games list / standings). iOS uses `Badge(text, style = .gray)`:
   fill `white @ 6%`, border `white @ 12%`, label = primary text, **system**
   semibold **10sp**, padding 12h/6v, capsule. Text is **all caps**: `"FINAL"` /
   `"TERCER LUGAR"` (call `.uppercase()`).

2. **Crest row** — `Row`, top-aligned: teamColumn(A) · "VS" · teamColumn(B).
   - "VS": Barlow Condensed **Bold**, `vsSize`, white, vertically centered to the
     crest height.
   - **teamColumn**: crest chip, then the name below (spacing ~10.dp).
     - Name: Barlow Condensed, **Bold if winner else SemiBold**, `nameSize`, all
       caps, `maxLines = 2`, auto-shrink to ~0.7. Color: winner or
       not-yet-decided → white; decided loser → `white @ 60%`.
   - **Crest chip** (diameter from the table):
     - With a logo URL: async image (Coil) in a circle, **1.dp** `gray700` outline.
     - No logo: **initial chip** — a circle filled `gray700`, the first letter of
       the team name in Barlow Condensed **Bold** at **diameter × 0.46**, white,
       with a **1.dp** `gray700` outline. Same footprint as a crest.
     - Placeholder-only team name comes from the placeholder string; when there's
       no team and no placeholder, the name is `"TBD"`.

3. **Result region**:
   - **Upcoming / scheduled** (has a time):
     - Date line: Barlow Condensed **SemiBold**, `dateSize`, letter-spacing ~2,
       `white @ 80%`, all caps. Format `"d MMMM, yyyy"` (e.g. `10 SEPTIEMBRE, 2026`).
     - Time line: Barlow Condensed **SemiBold**, `timeSize`, white. Format
       `"h:mm a"` with `AM`/`PM` (e.g. `9:00 PM`).
   - **No time** (and not live/finished): show **"SIN AGENDAR"** — Barlow Condensed
     **Bold**, size from the table, letter-spacing ~1, `white @ 70%`, single line,
     auto-shrink ~0.7, with a top padding of `Prominent ? 20 : 10` dp (it sits
     where the time normally would, since there's no date line above it).
   - **Live / finished**: scores `A` · `-` · `B`, Barlow Condensed **Bold**,
     `timeSize`. Winner digit = accent; decided loser digit = `white @ 50%`;
     otherwise white. Separator `-` at `white @ 50%`. (There is no live badge in the
     current design beyond your existing live treatment; add one on top if your app
     has a shared live badge.)

   > **Countdown pill: do NOT port it.** The iOS "FALTAN N DÍAS" pill was removed
   > from the final design. There is no countdown on this card.

4. **Venue footer** — **always shown**:
   - A divider: 1.dp tall, `white @ 15%`, horizontal padding 8.dp.
   - Then, spacing from the table, a row with a location-pin icon (~13.sp) + text:
     - If a venue exists: its name in the **system font**, weight **Medium**,
       `venueSize`, `white @ 90%`. If the venue has coordinates, make the row open
       maps (same behavior as your other venue rows).
     - If no venue: **"Ubicación por definir"**, system font Medium, `venueSize`,
       `white @ 55%` (reads as a placeholder).

### 3.3 Tap behavior

If the matchup is backed by a **real game**, the whole card navigates to your
existing game detail destination (Live / Result / Upcoming, same routing as your
other bracket cards). Placeholder-only cards are **not** tappable.

---

## 4. The four-layer animated background (`FinalCardBackground`)

A Composable taking `colorA`, `colorB` (resolved Colors), drawn bottom → top and
clipped to `RoundedCornerShape(16.dp)`. **Clip the whole stack to the card bounds**
— the blurred blobs are larger than the card, so if you let them size the layout
the glow bleeds past the rounded edges (this was a real iOS bug). In Compose:
size the background to the card (e.g. `Modifier.matchParentSize()` inside the
card's `Box`) and `.clip(RoundedCornerShape(16.dp))` so the oversized blobs are
clipped, not the layout inflated.

1. **Dark base** — a near-black radial gradient, center, `#1A1A1A → #0D0505`
   (roughly `white 0.10 → 0.02`). Everything above is additive light; keep it dark.
2. **Static split** — one ~**100°** linear gradient: `colorA @ 26%` at the leading
   edge → transparent at the middle → `colorB @ 26%` at the trailing edge. **Never
   animates.** Guarantees each side reads as its team.
3. **Three moving blobs** — each a blurred radial-gradient circle,
   **330×400 dp**, **blur 44 dp**, composited with **`BlendMode.Screen`**:
   - Blob A rests off the **left** edge (base X ≈ −120 dp), color `colorA`.
   - Blob B rests off the **right** edge (base X ≈ +120 dp), color `colorB`.
   - Blob C in the **center** (base X = 0), color = blend of A and B; it **pulses in
     place** (no travel).
   - Per-blob animation (`rememberInfiniteTransition`, `tween(easing = FastOutSlowInEasing)`,
     `RepeatMode.Reverse`, infinite):
     - travel offset — A: `dx = +95, dy = -120`; B: `dx = -95, dy = +120`;
       C: `dx = 0, dy = 0` (bounds are ±95 x / ±120 dp y),
     - scale `1.0 → 1.35`,
     - alpha `0.5 → 1.0`,
     - **loop durations 7000 / 9450 / 4900 ms** (base, ×1.35, ×0.7 — they must all
       differ or they visually sync).
   - **Blend mechanics:** wrap base + split + blobs in a layer rendered offscreen so
     `BlendMode.Screen` composes against the layers below instead of muddying —
     `Modifier.graphicsLayer { compositingStrategy = CompositingStrategy.Offscreen }`
     on the group, and draw each blob with `BlendMode.Screen` (e.g. a `Canvas`
     `drawCircle(brush = radialGradient, blendMode = BlendMode.Screen)` plus
     `Modifier.blur(44.dp)`, or a `Paint` with `blendMode`). Screen makes overlapping
     color add up to light.
4. **Scrim** — a vertical dark gradient (`black 55% → 15% → 55%`, top→bottom) plus a
   radial vignette (`transparent → black 45%`), over the color but under the text.
   It is what keeps text legible regardless of blob position — do not drop it, and
   verify ≥4.5:1 contrast at the worst frame (brightest blob under the text).

**Reduced motion:** if `Settings.Global.getFloat(resolver, ANIMATOR_DURATION_SCALE, 1f) == 0f`,
draw **layers 1, 2, 4 only** and skip the blobs entirely. It still reads as the
brand.

**Stop animating off-screen / backgrounded:** an infinite transition should not run
when the card is not visible or the app is backgrounded. Gate the animation on the
lifecycle (`LocalLifecycleOwner` + `repeatOnLifecycle(Lifecycle.State.RESUMED)`, or a
`derivedStateOf` on lifecycle state), so a scrolled-away or backgrounded card stops
its loop. Do not start it from initial composition unconditionally.

---

## 5. Color pipeline (client-side, cached)

Two colors drive a card, both extracted from the crests. **Run once per team and
cache** for the process lifetime; never sample per frame.

### 5.1 Extraction (pure) — `extractDominant(bitmap): Hsl?`

1. Downscale the logo to **~48×48** (`Bitmap.createScaledBitmap`, `filter = true`).
2. Read pixels; reject any pixel that cannot be a team color:
   **alpha < 200**, **lightness < 0.12 or > 0.92**, **saturation < 0.25**.
3. Bucket survivors by rounding each RGB channel **down to a multiple of 16**;
   count; the **fullest bucket wins**. Break count ties **deterministically** by the
   bucket key (e.g. smallest key) — do not rely on hash-map iteration order, or the
   same logo can resolve to different colors across launches.
4. Average the winning bucket, convert to HSL, and **lift** into the usable band:
   **saturation ≥ 0.55**, **lightness clamped to 0.42…0.62**.
5. Return `null` if nothing survives the filters.

> AndroidX `Palette` is a tempting shortcut but does **not** apply these specific
> filters/lift, so it will not match iOS. Implement the algorithm above. (You may
> use Palette's bitmap plumbing, but keep the filter/bucket/lift logic.)

### 5.2 Store — cache + off-main

A singleton (or DI-provided repository) exposing
`suspend fun color(teamId: Int?, logoUrl: String?): Hsl?`:
- memoize by `teamId` (distinguish "not cached" from "cached null");
- on first request, download the logo (Coil `ImageLoader`) and run
  `extractDominant` on **`Dispatchers.Default`** (off the main thread — decoding a
  full logo on main causes jank);
- coalesce concurrent requests for the same `teamId` onto one job.

### 5.3 Pair resolution — `resolveFinalPair(a: Hsl?, b: Hsl?): Pair<Color, Color>`

Fallback pair, in order: `#6B7280` (neutral gray), then `#1A2E05` (lime-950).
- **Both present** → if the two hues are within **25°**, rotate the second by **+40°**
  (mod 360) so the sides stay distinct; else use both as-is.
- **One missing** → the missing side takes fallback[0] `#6B7280`; the present side
  keeps its sampled+lifted color.
- **Both missing** → fallback[0] `#6B7280` and fallback[1] `#1A2E05`. **Never the same
  color on both sides.**
- Fallback values are used **as-is** (do **not** run the lift step on them).

### 5.4 Render-time

While extraction is in flight, render with the resolved **fallback** pair, then
**crossfade** to the resolved colors when they arrive (animate the card's colorA/
colorB, ~400 ms) — no gray→brand pop.

`FinalBracketScreen` resolves each card's pair by calling the store for
`homeTeam` (A) and `awayTeam` (B) of that matchup — **home → A, away → B, for both
the final and the third-place card** (watch for a copy/paste swap here).

---

## 6. Tests

Keep the decision logic pure and unit-test it (JVM tests, no Android framework):

- **`extractDominant`** — a mostly-black bitmap with an orange region resolves to a
  lifted orange hue (sat ≥ 0.55, light 0.42–0.62); an all-gray bitmap resolves to
  `null`; hue distance wraps (350° vs 10° = 20°).
- **`resolveFinalPair`** — near-identical hues get the second rotated +40°;
  one-missing takes fallback[0] and keeps the other sampled; both-missing yields the
  two distinct fallbacks and never gray twice.
- **`hasInfo`** — true iff hasGame or any placeholder field / scheduledTime / venue
  is present.

(There is no countdown to test — the pill was removed.)

---

## 7. Gotchas / parity checklist

- Card is **content-sized**, not full-screen; the single Final card is **top-aligned**
  with empty space below (like the reference), not centered or stretched.
- **Clip the animated background to the card**, or the blurred blobs bleed past the
  rounded corners.
- **Dense mode** applies to **both** cards in the two-card layout and shrinks crest +
  time + gaps + padding so they fit without scrolling.
- Stage label uses your **design-system gray Badge**, **all caps** — not a bespoke
  pill.
- Venue uses the **system font**; everything else uses **Barlow Condensed**.
- No-logo chip fill + crest outline use **`gray700` `#252525`** (a design token), not
  an ad-hoc gray.
- **No countdown pill.**
- Extraction runs **once per team, off the main thread, cached**; colors **crossfade**
  in from the fallback pair.
- Honor **reduced motion** (layers 1/2/4 only) and **stop the animation** when
  off-screen / backgrounded.
- All user-facing strings are **Spanish**; dates in **es_MX / America/Tijuana**.
