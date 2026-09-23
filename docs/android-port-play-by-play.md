# Android Port — Play by play (game result)

A self-contained implementation prompt for porting the iOS **Play by play** section
of the game result screen to the Android app (Jetpack Compose). iOS point sizes map
1:1 to Android `dp`/`sp`.

**Assumptions (confirmed):** the Android app already renders the game result / game
detail screen from `tournaments/{id}/games/{gameId}.json` and has equivalents of the
iOS `GameDetailResponse` (`long_name_stats`, `short_name_stats`, `game`), `game.team_stats`
(each with `id`, `team_name`, `score`, `team_logo`, player list), and whatever it uses
today for the score card and the player-stats table. This prompt only ADDS the new
section + the tab that reveals it. Reuse your existing models and networking; do not
re-parse the API from scratch.

**What this is:** a chronological in-game event log (baskets, fouls, substitutions),
grouped by period, shown on a second tab of the result screen. It appears **only** when
the endpoint includes a non-empty `play_by_play` array — many games don't have it.

**Test data:** `https://elite.getbrackets.app/api/tournaments/62/games/2303.json`
(99 events, periods `2P` + `1P`). Concrete expected values from this game are listed in
§7 — use them as your acceptance tests.

---

## 0. Tokens & fonts

Use whatever your app already defines; these are the iOS values.

- **Accent lime:** `#C7F24A` (design) / `#A3FF12` (code) — winner's score in the top
  card, and the `Entra` action label.
- **gray700** = `#252525` — top-card background, period-banner background, row
  separators, and the card's side border.
- **gray800** = `#1A1A1A` — the table (rows) background.
- **gray400** = `#9CA3AF` — player number, team-name subtitle, neutral action labels,
  the "FINAL" label.
- **gray500** = `#6B7280` — losing score, the score `-` dash, and the dimmed side of a
  row's running score.
- **primaryText** = white — player name, the emphasized side of a row score, the period
  banner text, and team names in the top card.
- **red / "live"** = `#EB3340` (iOS `Color(0.92, 0.20, 0.25)`) — `Sale` and `Pérdida`
  action labels.
- **Tab underline:** `sky900` = `#1A17D3` (the existing blue tab indicator).
- **Score face:** **Barlow Condensed** — used ONLY for the two big scores (top card and
  each row's running score). Everything else uses the **platform system font** (Roboto).
- **Locale/timezone:** unchanged from the rest of the app (`es_MX`, `America/Tijuana`).

Corner radius for the card: **16.dp**. Screen (card outer) padding: **12.dp**.

---

## 1. Where it plugs in

On the game result screen, decide by whether the feed exists:

```
hasPlayByPlay = (game.play_by_play?.isNotEmpty() == true)
```

- **`hasPlayByPlay == false`** → render the screen exactly as today (score card + player
  stats + player of the game). **No tabs.** Nothing changes for these games.
- **`hasPlayByPlay == true`** → under the score card, show a **two-tab bar**
  (`Stats` | `Play by play`) using your existing underlined tab component (blue `sky900`
  indicator, selected label white, others gray). **Default selection = Stats**, so the
  common path is unchanged until the user taps. `Stats` shows today's content; `Play by
  play` shows the new section (§4). No tabs are needed inside the section.

The tab bar is full-bleed (edge to edge); the cards keep the 12.dp screen padding.

---

## 2. Data model

Add a `PlayByPlayEvent` and an optional field on the game detail. All fields nullable-safe.

```
PlayByPlayEvent(
  id: Int,                 // "id"
  statName: String,        // "stat_name"
  period: String,          // "period"  e.g. "2P", "1P"
  scoreA: Int,             // "score_a" — running total AFTER the play
  scoreB: Int,             // "score_b"
  playerFirst: String,     // "player_first"
  playerLast: String,      // "player_last"
  playerNumber: Int?,      // "player_number"
  teamName: String,        // "team_name"
  teamLogo: String?,       // "team_logo"  (path or absolute; build URL like other logos)
  teamStatId: Int          // "team_stat_id"  (matches team_stats[].id)
)

game.playByPlay: List<PlayByPlayEvent>?   // "play_by_play" — may be absent, null, or []
```

The feed is ordered **newest-first** (highest score / latest play at index 0).

---

## 3. The transform (pure, unit-tested) — the important part

Turn the raw feed into period-grouped display rows. Keep this free of UI so you can test
it. Output types:

```
enum Side { A, B }
enum ActionKind { SCORING, ENTRA, SALE_PERDIDA, NEUTRAL }   // drives label color
enum Emphasis { LEFT, RIGHT, NONE }                          // which running score to bold

Row(
  id, playerNumber, playerName,       // playerName per §4.3
  teamName, teamLogo,
  actionLabel: String, actionKind: ActionKind,
  leftScore: Int, rightScore: Int,    // oriented to header team order (left = teams[0])
  emphasis: Emphasis                  // NONE => don't show the score at all
)
Period(id: String, title: String, rows: List<Row>)   // title e.g. "PERIODO 2"
```

Build inputs: `events` (as decoded), `teams` = `team_stats` mapped to `(id, score)` **in
their existing order** (that order defines the header's left/right), and `longNameStats`.

### 3.1 Action label + kind

```
when (statName) {
  "two_pm"   -> "2 puntos"           to SCORING
  "three_pm" -> "3 puntos"           to SCORING
  "ftm"      -> "Tiro libre"         to SCORING
  "pfs"      -> "Falta personal (N)" to NEUTRAL     // N = running foul count, §3.4
  "to"       -> "Pérdida"            to SALE_PERDIDA
  "sale"     -> "Sale"               to SALE_PERDIDA
  "entra"    -> "Entra"              to ENTRA
  else       -> (longNameStats[statName] ?: statName) to NEUTRAL
}
```

Only `SCORING` rows display a running score. `pfs` without a count → `"Falta personal"`.

### 3.2 Side inference (the gotcha — do not skip)

`score_a`/`score_b` are **NOT** aligned to `team_stats` order. In the test game
`team_stats[0]` is "FOUL Y CUENTA" but it drives `score_b`. So map each `team_stat_id`
to a `Side`:

1. Walk events **chronologically** (reverse the feed). Track `prevA, prevB`. For a
   scoring stat (`two_pm`/`three_pm`/`ftm`): if `scoreA > prevA` and this `teamStatId`
   is unmapped → it's `Side.A`; if `scoreB > prevB` and unmapped → `Side.B`. Then update
   `prevA/prevB`. First assignment per team wins.
2. Fallback for still-unmapped teams: `finalA = events.first().scoreA`,
   `finalB = events.first().scoreB`; a team whose `score == finalA` → A (if A free), else
   `== finalB` → B.
3. Last resort: assign any remaining team to whichever side is still free.

### 3.3 Orientation (so the row score matches the header columns)

`leftSide = sideOf(teams[0].id)`. For each event:
`leftScore = if (leftSide == A) scoreA else scoreB`, `rightScore =` the other.
For a `SCORING` row: `emphasis = if (actingTeamSide == leftSide) LEFT else RIGHT`.
Non-scoring rows: `emphasis = NONE`.

### 3.4 Running foul tally

Walk chronologically; key `= "$teamStatId#${playerNumber ?: -1}#$playerLast"`; increment
per `pfs`; store the resulting count on that event's id → feeds `"Falta personal (N)"`.

### 3.5 Grouping

Group rows by `period`, **preserving the feed's period order** (so `2P` then `1P`), rows
newest-first within each. `title`: `"2P" -> "PERIODO 2"`, `"1P" -> "PERIODO 1"` (strip a
trailing `P` and prefix `"PERIODO "`; otherwise uppercase the raw value).

---

## 4. The UI — one connected card

The section is **one card** (12.dp horizontal screen padding): a top score header with
**rounded top corners only** that flows straight into the table below (**rounded bottom
corners**), so header and table read as a single card. A **1.dp `gray700` border** wraps
the whole card. Only the period banners are sticky.

Put the whole thing inside the screen's scroll. Use a `LazyColumn` with **sticky headers**
for the periods (`stickyHeader { periodBanner }`, then `items(period.rows)`), so the
"PERIODO N" banner pins to the top of the viewport while its rows scroll under it. The
score header is a normal item ABOVE the lazy content — it scrolls away; it does **not**
pin.

### 4.1 Score header (top of the card)

- Background **gray700**, rounded **top** corners (16.dp), square bottom. Padding 16.dp.
- A 1.dp black-30% hairline along its bottom edge.
- Centered column: **"FINAL"** (system, 11.sp, semibold, letter-spacing ~3, gray400) above
  the score row.
- Score row, baseline-aligned, spacing 10.dp:
  `leftScore` — **Barlow Condensed semibold, 38.sp**, color = accent lime if it's the
  winner else gray500; then `-` (Barlow Condensed semibold, 26.sp, gray500); then
  `rightScore` (same rule). Winner = the higher of the two team scores.
- Teams sit on the far left/right via two equal flexible halves so the score stays
  centered. **Each team chip is a vertical stack: logo (40.dp circle) on top, team name
  below** (system, 13.sp, semibold, white, centered, 1 line, ellipsize). Left chip hugs
  leading, right chip hugs trailing.

Header team data: `teams[0]` = left, `teams[1]` = right; names/logos/scores from
`team_stats` (fall back to your existing `game_sets` fields if you use them).

### 4.2 Period banner (sticky)

Full card width, **gray700** background, vertical padding 10.dp, centered text: system,
13.sp, semibold, letter-spacing ~1.5, **white**. Opaque (it covers rows scrolling under).

### 4.3 Row

Layout: `[avatar]  [name line + team subtitle]  …spacer…  [running score]`

- **Padding:** leading **8.dp**, trailing **14.dp**, vertical **17.dp**. Avatar↔text gap 10.dp.
- **Avatar:** the event's `team_logo` in a 36.dp circle (thin outline). Fallback: the
  player number on a dark gray circle.
- **Name:** `playerName` = **first word of `player_first` + first word of `player_last`**
  (e.g. "Mauricio Jose Castro Dominguez" → "Mauricio Castro"). Rendered as
  `"#<number> "` (system, 15.sp, **semibold**, gray400) + `"<name>"` (system, 15.sp,
  **bold**, white), single line, ellipsize.
- **Action label:** `"- <label>"` right after the name, system 14.sp semibold, never
  truncated (give it layout priority). Color by `actionKind`: SCORING/NEUTRAL → gray400,
  ENTRA → accent lime, SALE_PERDIDA → red.
- **Team subtitle** (second line): `teamName`, system 11.sp medium, gray400, 1 line.
- **Running score** (only when `emphasis != NONE`): a tight row (spacing **3.dp**) of
  `leftScore`, `-`, `rightScore` in **Barlow Condensed bold, 22.sp**, monospaced digits.
  The `emphasis` side is white; the other side and the dash are gray500.
- **Separator:** a 1.dp **gray700** line, **full width (edge to edge)**, drawn at the
  **top** of every row EXCEPT the first row of each period (so no full-width line ever
  crosses the rounded bottom corners; the banner and header hairline cover the other
  boundaries).

### 4.4 Table background

The lazy content sits on a **gray800** fill with rounded **bottom** corners (16.dp), so
rows read as gray800 and the header (gray700) is a touch lighter above them.

---

## 5. Exact metrics recap

| Element | Font | Size | Weight | Color |
|---|---|---|---|---|
| FINAL label | system | 11 | semibold | gray400 |
| Top score number | Barlow Cond. | 38 | semibold | lime (winner) / gray500 |
| Top score dash | Barlow Cond. | 26 | semibold | gray500 |
| Header team name | system | 13 | semibold | white |
| Period banner | system | 13 | semibold | white |
| Player number | system | 15 | semibold | gray400 |
| Player name | system | 15 | bold | white |
| Action label | system | 14 | semibold | by kind (gray400 / lime / red) |
| Team subtitle | system | 11 | medium | gray400 |
| Row score | Barlow Cond. | 22 | bold | white (emph) / gray500 |

Spacings: card radius 16, screen padding 12, header padding 16, row leading 8 / trailing
14 / vertical 17, avatar 36, header logo 40, score-row spacing (top) 10, (row) 3.

---

## 6. Colors reference

`gray700 #252525` (header + banner + separators + border), `gray800 #1A1A1A` (rows),
`gray400 #9CA3AF` (secondary text), `gray500 #6B7280` (dimmed scores/dash), lime
`#C7F24A/#A3FF12` (winner + Entra), red `#EB3340` (Sale/Pérdida), white (primary),
`sky900 #1A17D3` (tab underline).

---

## 7. Parity checklist / acceptance tests

Against `tournaments/62/games/2303.json`:

- [ ] Games without `play_by_play` show **no tabs** and are visually unchanged.
- [ ] Two periods, in feed order: **"PERIODO 2"** (60 rows) then **"PERIODO 1"** (39 rows).
- [ ] Side inference: team `4601` (FOUL Y CUENTA, final score 55) → **Side.B**; team
      `4602` (score 15) → **Side.A**. `team_stats[0]` is NOT automatically side A.
- [ ] Header shows `team_stats[0]` left / `[1]` right; winner's number is **lime**.
- [ ] A scoring play by the left team emphasizes the **left** number; by the right team,
      the **right** number. Its `leftScore` = the left team's running total.
- [ ] Substitution / foul / turnover rows show **no** running score.
- [ ] Labels: `two_pm`→"2 puntos", `three_pm`→"3 puntos", `ftm`→"Tiro libre",
      `sale`→"Sale" (red), `entra`→"Entra" (lime), `to`→"Pérdida" (red).
- [ ] Running fouls: event `77693` → "Falta personal (1)"; `77699` → "Falta personal (3)";
      `77678` → "Falta personal (1)". (Count is per player, across periods.)
- [ ] Player names collapse to two words (first + first): e.g. "Mauricio Jose Castro
      Dominguez" → "Mauricio Castro".
- [ ] "PERIODO N" banners **pin** to the top while scrolling; the score header scrolls away.
- [ ] Row separators are full-width gray700; the card has a gray700 side border; header
      (gray700) is lighter than rows (gray800).

**iOS source of truth:** `Brackets/PlayByPlay.swift` (transform), `Brackets/PlayByPlayView.swift`
(UI), `Brackets/GameResultView.swift` (tab wiring), `BracketsTests/PlayByPlayTests.swift`
(test values).
