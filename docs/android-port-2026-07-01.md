# Android Port — iOS Changes from 2026-07-01

Detailed, self-contained implementation prompts for porting today's iOS ("Brackets") view redesigns to the Android app. Each section is derived directly from a git commit and is written to be stack-agnostic — adapt to Jetpack Compose or XML Views.

**Commit map:**

| View | iOS commit(s) |
|------|---------------|
| Tournament List — Varonil/Femenil rama pills | `5f1de27` |
| Standings — collapsible two-tone table cards | `c956a2e` |
| Games — group carousel, banners, unified cards | `58a45ee` |
| Bracket — multi-bracket tabs, placeholders, visual redesign | `3f2d0b1` + `aab472a` |
| Top Stats — podium card + filtered full-leaderboard screen | `3b83232` |

> ⚠️ **Accent color:** the lime accent is `#A3FF12` in code, while CLAUDE.md/design docs say `#C7F24A`. The prompts reference both — use whichever token your Android app already defines as the app accent, and stay consistent. Text/content placed on the accent is black `#000000`.

---

# 1. Tournament List — Varonil/Femenil rama pills
*(iOS commit `5f1de27`)*

## Context
This is the **Tournament List** screen (scrollable list of tournaments/categories shown after selecting a league; header "Selecciona una categoría" + vertical list of cards). Add a **gender ("rama") filter**: two independent pill toggles **"Varonil"** (male) / **"Femenil"** (female). Dark mode only; accent lime `#C7F24A`; text in Spanish (`es_MX`).

## Data model
Each tournament has a nullable integer `gender`: `0` = Varonil, `1` = Femenil, `null` = none. Add a `Gender` enum with fixed order `[Varonil(0), Femenil(1)]`, display names `Varonil`/`Femenil`.

## Derived state (ViewModel)
1. **`availableGenders`** — distinct **non-null** genders present, in fixed order `[Varonil, Femenil]` (filter the enum cases; do not derive order from data).
2. **`showGenderTabs`** — `true` only when `availableGenders.size >= 2`.
3. **`selectedGender`** — default = **Varonil**.
4. **`filteredTournaments`**:
   - `showGenderTabs == false` → all tournaments unfiltered.
   - `showGenderTabs == true` → tournaments where `gender == null` **OR** `gender == selectedGender`. **Null-gender tournaments always appear under whichever tab is selected.**

## Visibility & placement
- Render the pill row **only when `showGenderTabs == true`**.
- Position: between the header and the first tournament card.

## Pill styling
Horizontal row of **two independent capsule toggles** (NOT a segmented control with sliding indicator), **left-aligned** (trailing spacer / `Arrangement.Start`).
- Gap between pills: **8dp**. Row horizontal padding ≈ **24dp** (match your list content margin).
- Each pill: label = display name; font **15sp semibold**; inner padding **20dp horizontal / 10dp vertical**; fully-rounded capsule shape; fill only, no stroke.
- **Selected:** fill accent `#C7F24A`, text black `#000000`.
- **Unselected:** fill `#262626`, text secondary gray (`#8E8E93`-ish).
- Optional spring animation on fill change. Default: Varonil selected (lime), Femenil dark.

## Acceptance
Pills appear only when both genders present; hidden (full list) with 0–1 genders; Varonil default & first; selecting filters to that gender + all null-gender tournaments.

---

# 2. Standings — collapsible two-tone table cards
*(iOS commit `c956a2e`)*

## Objective
Render standings as a **compact table** instead of per-team cards. Grouped standings → **one collapsible card per group**; flat standings → the same table in a single always-expanded card. View/layout only — no data/sorting/API changes. iOS pt → dp 1:1.

## Constants
- Positive/accent green `#A3FF12` (text on it = black); negative = red; neutral = white.
- Primary text white `#FFFFFF`; secondary gray `#8E8E93`.

## Data (unchanged, for reference)
Each row: `position` (1-based), `teamName`, `total`→**J**, `wins`→**G**, `losses`→**P**, `pointsFor`→**FAV**, `pointsAgainst`→**CON**, `avg` (nullable)→**AVG**, `pointDifferential` (signed)→**DIF**, `tiebreaker` (nullable → info icon).
Tournament has `usesAverage`: **last column is AVG when true, else DIF** (header + every row). Standings arrive **flat** (single ordered list) or **grouped** (named groups, each with id=name + ordered list) — keep existing parsing.

## Two-tone surfaces
- Header band (lighter): `#292929` — behind card title/chevron AND column-label row.
- Rows area (darker): `#1A1A1A`.
- Row divider hairline: `#333333` — between adjacent rows only.
- Card clipped to **16dp** corner radius.

## Fixed column widths (header + rows must align; 4dp column spacing)
| Col | Width | Align |
|---|---|---|
| `#` | 16dp | left |
| `EQUIPOS` | flexible | left, wraps |
| tiebreaker icon | 16dp | between name and J |
| `J` `G` `P` | 18dp each | center |
| `FAV` `CON` | 30dp each | center |
| `AVG`/`DIF` | 50dp | center |

Order: **# · EQUIPOS · (icon) · J · G · P · FAV · CON · AVG|DIF**

## Column-label row
Labels `#`, `EQUIPOS`, empty 16dp spacer, `J G P FAV CON`, `AVG`/`DIF`. Typography **10sp semibold, gray, UPPERCASE**. Padding **14dp H / 8dp V**. Background = header band.

## Team row (tappable → team detail, passing standing + tournament id/name + rank)
Column spacing 4dp, vertical padding 10dp.
1. Rank: 13sp bold white, 16dp, left.
2. Team name: 14sp semibold white, flexible, left, **wraps to multiple lines** (only element allowed to wrap).
3. Tiebreaker column (16dp): info-circle icon (~12sp gray, independently tappable → existing tiebreaker sheet) if present, else empty spacer.
4. J/G/P: 14sp regular gray, centered in 18dp.
5. FAV/CON: 14sp regular gray, centered in 30dp.
6. Last column (50dp): AVG pill or DIF cell.

**AVG pill:** value to **3 decimals** (null → `-`); 13sp semibold, single line, min-scale ~0.6; color ≥1 → green, <1 → red, null → gray; rendered as pill (6dp radius, background = text color @15% opacity, padding 6dp H / 3dp V).
**DIF cell:** signed int, **leading `+` for positive**, `0` for zero; 13sp semibold, single line, min-scale ~0.6, no background; >0 green, <0 red, 0 white.

## Table body (shared)
Vertical stack, no gap: column-label row (header band) then rows area (rows band) with 14dp horizontal padding and hairline dividers.

## Collapsible group card
Header bar (background `#292929`, padding 14dp H/V, full width): left = group name (first letter capitalized), 18sp bold white; right = chevron (13sp semibold gray) **rotated 90° when expanded**, animated. Tap toggles. Expanded → show table body; collapsed → header only. Card clipped 16dp.
List: scroll view, cards separated 20dp vertically, 6dp horizontal padding each, 8dp top / 20dp bottom content padding.

## Flat standings
Same shared table body in one always-visible card (16dp corners, 6dp H padding), no header/chevron.

## Collapse behavior (careful)
In-memory set of expanded group ids (not persisted). **On first successful load of grouped standings only:** expand just the **first group** (guard with a one-time flag so refresh doesn't re-expand a user-collapsed group). Tap toggles. Animate expand/collapse + chevron with a **spring** (~0.3s response, ~0.8 damping).

## Removed / out of scope
Removed: old per-team card, position circle badge, separate stat columns w/ captions, win-loss record badge. Unchanged: "Campeón" sub-tab & podium, sub-tab selector, loading/error/empty states, tiebreaker sheet, team-detail nav args, grouped-vs-flat parsing & sort.

---

# 3. Games — group carousel, banners, unified cards
*(iOS commit `58a45ee`)*

## Overview
Rebuild the Games tab into: (1) top filter tabs, (2) a group/bracket chip carousel, (3) date-grouped list of unified cards. Dark mode; Spanish `es_MX`; dates in `America/Tijuana`. Screen H padding 12dp. Spacing: small 8 / medium 12 / standard 16 / large 20. Card radius 16dp.

## Data additions
Per-game: `group: String?` (e.g. "Grupo 1"; null for playoffs), `bracket: String?` (e.g. "Playoffs"; null for regular season). Top-level `brackets: [{name, position:Int?, type_label:String?}]`. All decode-if-present; existing games-by-date decoding unchanged.

## 1. Top filter tabs
Three filters: `live`→"En Vivo", `upcoming`→"Próximos", `completed`→"Resultados". **Remove the old "Todos" tab.** Available: `[En Vivo, Próximos, Resultados]` if any live game, else `[Próximos, Resultados]`. Default = `live` if live games exist, else `upcoming`.
Predicates: live → isLive; upcoming → not finished & not live; completed → finished & not live.
Live interplay: when live detected & current tab is upcoming → auto-switch to En Vivo; when no more live & current is En Vivo → fall back to upcoming & stop timer. All old fallbacks to "Todos" now go to `upcoming`. Tabs: 12dp H padding, 12dp top / 8dp bottom.

## 2. Group/bracket chip carousel
Row beneath tabs, 12dp bottom padding, height 44dp. Build chips from games matching the **active tab**:
1. **Group chips first** — distinct non-null `group`, **natural numeric sort** on trailing integer (Grupo 1,2,…,10,13 — NOT lexical).
2. **Bracket chips after** — distinct non-null `bracket`, ordered by `brackets[].position` asc (unknown/null → after, then string compare).
Chip identity = kind + name. Game matches chip when group/bracket equals chip name.

**Selection (careful):** exactly one chip always selected (no "All"). First load: first chip with games under active tab (guard: run once). **On tab change: reset to first chip of recomputed list.** Keep current chip if still valid, else first valid.

**Chip style:** text 14sp semibold. Selected = transparent fill + **2.5dp lime accent stroke**, white text. Unselected = fill `#141414`, text `#D4D4D4`. Inner padding 18dp H / 9dp V. Gap 8dp. Spring on selection (~0.3s, ~0.7 damping).

**Overflow arrows:** when content overflows viewport, show both left+right chevrons **inline** (`[◀] [chips] [▶]`, no overlap). Circular 36×36dp, fill `#242424`, chevron 14sp bold `#D4D4D4`, shadow black@40% blur~4dp. Tap scrolls ~one viewport (page = floor(viewport/avgChipWidth), min 1); track leadingIndex, reset to 0 when chip list changes. Row H padding 12dp.

## 3. Date grouping
Filter each date group to games matching active tab AND selected chip; drop empty groups. Sort: **upcoming/live ascending**, **completed descending**. Preserve "scroll to nearest upcoming date."
**Date header** (row, 8dp spacing, 12dp H padding): calendar icon 14sp semibold lime; date text 16sp bold white formatted `es_MX`/`America/Tijuana` → "Jueves, 18 de Junio" (capitalized weekday + ", " + day + " de " + capitalized month); count badge "N Juegos" (singular "1 Juego"), 12sp semibold gray, capsule fill `#333333`, padding 10dp H / 4dp V. Section spacing ~20dp; header→cards ~12dp.

## Unified game card (same style for upcoming + finished)
Background `#1C1C1C`, radius 16dp, clip contents. No border, no special full-card bg colors.

**Optional top banner** (by `stage`, case-insensitive): `stage=="final"` (exact) → "Final", fill lime, black text. Else contains `"semifinal"` (covers "Semifinales") → "Semifinal", fill `#3B36E6`, white text. Else no banner. Banner: label left (row + spacer), 15sp bold, padding 14dp H / 8dp V, full width, top corners follow 16dp clip. **`final` must be exact-match** (don't match "Cuartos de final").

**Body:** 16dp padding all sides, 14dp vertical spacing between the 3 rows.

**Teams row:** home (flex) · center (fixed 130dp) · away (flex), spacing ~20dp.
- Team section: circular logo 46×46dp (fill/clip; fallback circle `#262626` + initials 16sp bold white — ≥2 words: first letters of first two words; else first 3 chars; else "TBD"). Winner ring: if finished & winner, lime 2dp stroke sized 54×54dp. Name below: 14sp semibold white, centered, max 2 lines, min-scale ~0.8, "TBD" if unknown.
- Center: if finished → `home - away` scores (24sp bold; winner number lime, other white; dash 18sp `#737373`). No "VS", no in-card date. If not finished + time → start time `h:mm a` (`es_MX`/`America/Tijuana`), 18sp bold white. If no time → "—" 18sp bold `#737373`.

**Venue row** (only if venue): reuse shared venue label — name + `" - {court}"` when court exists; 12–13sp lime accent; tappable Maps link with pin icon + underline when coords exist, else plain gray `#808080` non-tappable. Centered.

**Tags row** (centered, 8dp spacing): pills 12sp semibold, padding 10dp H / 5dp V.
- Left stage tag (gray): fill `#333333`, gray text, stage capitalized. **Suppress entirely when a banner shows** (no duplicate stage).
- Right group/bracket tag (purple): fill `#230E2E`, white text, = `group` else `bracket`; omit when both null.

Combinations: regular → gray "Ronda Regular" + purple "Grupo N"; QF/other playoff → gray stage + purple "Playoffs"; Final → lime banner + purple, no gray; Semifinal → blue banner + purple, no gray.

## Out of scope
Live game card's distinct red-bordered styling unchanged; game-detail navigation unchanged; no API changes; no changes to Bracket/Standings/Stats. Selected chip in-memory only.

---

# 4. Bracket — multi-bracket tabs, placeholders, visual redesign
*(iOS commits `3f2d0b1` + `aab472a`)*

## Overview
Horizontal single-elimination bracket: round columns (Octavos → Cuartos de final → Semifinal → Final), connector lines, matchup cards. Dark mode; Spanish `es_MX`; dates in `America/Tijuana` (offset-stripped, parse in that TZ — never UTC/ISO). iOS pt → dp. Accent lime `#C7F24A` (text on it = black).

**Grays:** `#171717` card bg (white .09), `#212121` round-pill (.13), `#242424` chevron btn (.14), `#2E2E2E` neutral avatar (.18), `#333333` divider (.20), `#404040` connector/unplayed-name (.25), `#4D4D4D` empty/no-team + unplayed score (.30), `#666666` footer/date (.40), `#737373` unlinked venue (.45), `#808080` neutral score/initials (.50), `#8C8C8C` neutral name (.55), `#999999` round-pill title (.60), `#D4D4D4` chip/chevron (.83). `#141414` chip unselected fill (.08).

## Data additions
Games response may include `brackets: [{name, position:Int?, type:String?, type_label:String?, game_placeholders:[...]}]`. `type` lowercased matters: `"octavos"`, `"quarterfinals"`, `"semifinals"` (falls back to tournament `bracketType`).
GamePlaceholder (all nullable): `stage`, `bracket_id:Int?` (1-based slot index), `team_a`/`team_b` (seed labels e.g. "1° Lugar"), `game_time:Date?`, `venue` (object `{name,court_number,lat,lng}` OR plain string — tolerate both).
Each Game has `bracket` (=owning bracket name), `stage`, `bracketId`, teams, scores, winner, isFinished, isLive, gameTime, venue. **When rebuilding a game from detail refresh, preserve its `group` and `bracket` fields** (were being dropped).

## Multi-bracket chip carousel (only when `brackets.count >= 2`)
`selectedBracketName: String?`; init once (guard) to first bracket after sorting by `position` asc (nulls last). Reusable `ChipCarousel` (same as Games): height 44dp, chips 14sp semibold, capsule, padding 18dp H / 9dp V, 8dp gap; unselected text `#D4D4D4` fill `#141414`; selected text primary + 2.5dp accent border transparent fill; spring on selection; overflow chevrons (36dp circle `#242424`, icon 14sp bold `#D4D4D4`, shadow black@40% blur~4dp, scroll ~one viewport, reset leadingIndex on list change).
Derived: `selectedBracket` by name; `activeType = (selectedBracket?.type ?? tournamentBracketType)?.lowercase ?? ""`; `bracketGames = brackets empty/no selection ? all games : games.filter { bracket == selectedBracketName }`. **All slot lookups use `bracketGames`.** On selection change: reset pager to page 0, clear drag.

## Building rounds (seeding + propagation)
Ordered round columns, each with name + ordered matchups; Final round also carries optional `thirdPlace`. Carry `previous` forward:
1. **Octavos** — only if `activeType=="octavos"`. Slots 1–8, stage "Octavos de final", no propagation. `previous = 8`.
2. **Cuartos de final** — if `octavos` OR `quarterfinals`. Slots 1–4, stage "Cuartos de Final". If `previous` non-empty: QF slot `s` sources `previous[(s-1)*2]` & `+1` (winners). If empty: no propagation. `previous = 4`.
3. **Semifinal** — always. Slots 1–2. Sources `previous[(s-1)*2]`,`+1` winners. `previous = 2`.
4. **Final** — always. One match slot 1 stage "Final", from SF pair 0 (both winners). Plus **Tercer Lugar** slot 1 stage "Tercer Lugar", from SF pair 0 **losers**. Final column carries `thirdPlace`.

Propagation helper: target slot `i` (0-based) sources `previous[2i]`,`previous[2i+1]`; home=winner (or loser for 3rd place) of first, away=of second. Winner = side with `isWinner==true`. **Seeding convention 1v8/4v5/2v7/3v6** — pairing comes from API `bracket_id`/game data, don't compute client-side; preserve slot ordering so adjacent matchups pair (0&1→next 0, 2&3→next 1).

**Resolve a matchup:** first find a real Game from `bracketGames` matching stage (§stage-matching), then: single-slot stages ("final"/"tercer lugar") → if exactly one game use it, else match `bracketId==slot`; multi-slot → `bracketId==slot`. If found: use game teams/scores/winner flags (`homeIsWinner = isFinished && winner.id==homeTeam.id`), `hasGame=true`, scheduledTime/venue from game. If none: placeholder — find GamePlaceholder in `selectedBracket.game_placeholders` matching stage AND `bracket_id==slot`; `homeTeam/awayTeam = propagation.home/away`; no scores; `hasGame=false`; `homePlaceholder = placeholder.team_a` only if propagation.home is null (same for away); scheduledTime/venue from placeholder. **Team precedence: real advancing team → seed label → "TBD".**

## Layout constants
Card width 180dp, **card height 146dp** (fixed — reviewed final value, not 138/110), connector column 36dp, round column = 216dp.
Columns laid left→right, top-aligned; within a column cards stacked vertically + connector column to the right (except last round). Final column stacks Tercer Lugar card below Final.

## Round headers (all rounds except last; last renders inline above its card, 10dp bottom padding)
Header aligns over its column (card width 180dp + 36dp trailing). Content (vertical, left-aligned, 4dp): pill = round name UPPERCASE, 11sp bold, tracking 0.5, `#999999`, padding 14dp H / 6dp V, capsule fill `#212121`; below (if round has date): earliest `scheduledTime` among matchups (incl. Final's thirdPlace) formatted `"d MMM"` `es_MX`/TZ → "29 jun", 12sp `#666666`, 4dp left. **Sticky** vertically; in paged layout offset in lockstep with pager + clipped. Row: medium top padding, 16dp bottom.

## Matchup card (borderless — removed old `isFinal` accent-border param)
180×146dp, bg `#171717`, radius 14dp, clip. If no scheduledTime AND no venue → center content vertically; else top-align. Stack: home row, away row, footer. Tappable → game detail when `hasGame`; placeholders non-navigating.

**Team row** (8dp spacing, padding 10dp H / 8dp V): `displayName = team?.name ?? placeholderName ?? "TBD"`; `hasTeam = team!=null || placeholderName!=null`.
- Avatar 30dp circle, **initials only (no logos)**: ≥2 words → first letters of two words; else first 2 chars. Winner: fill accent, initials black 11sp bold. Else: fill `#2E2E2E`, initials `#808080` 11sp bold.
- Name: fills width, left; 14sp; bold if winner else semibold; winner→primary, hasTeam→`#8C8C8C`, no team→`#4D4D4D`; up to 2 lines, min-scale 0.7, tail truncate.
- Score: number or `"-"`; 20sp heavy; winner→accent, has score→`#808080`, no score→`#4D4D4D`.
- Winner band: RoundedRect radius 8dp inset 4dp H, fill accent @10% when winner, else transparent. Unplayed → both rows neutral, no band.

**Footer** (only if scheduledTime OR venue; vertical 2dp, full width, 10dp H): divider `#333333` 1dp with 6dp top padding, then content 6dp top / 8dp bottom. If scheduledTime: clock icon (~10sp) + `"d MMM · h:mm a"` (`es_MX`/TZ, AM/PM forced, middle-dot U+00B7) 11sp medium, both `#666666`. If venue: venue row below.

**Venue row:** with Maps URL (has lat/lng) → pin icon (10sp) + name (11sp) both accent, single line tail-truncate, tappable → open Maps, 3dp spacing, centered, 8dp H. Without → name only 11sp `#737373`, no icon, not tappable.

**Live badge:** if game isLive, overlay live badge at top edge, offset y −9dp (reuse app live indicator). Preserve live-refresh polling.

## Paging
`rounds.count <= 2` → static (header + vertical scroll body, 100dp bottom padding, no horizontal drag). `> 2` → horizontal pager stepping ~2 columns: `roundStep=216dp`, baseOffset `= -currentPage*roundStep + screenPadding`, `maxPage = max(0, rounds.count-2)`; drag gesture (min 30dp) updates live dragOffset, snap on release (clamped), animate; header + body scroll together (same offset, each clipped); vertical scroll independent. On bracket change reset page & drag.

## Matchup vertical spacing & connectors
Base spacing round 0: `80dp` if `activeType=="semifinals"` else `24dp`. Round `n>0`: `spacing(n) = spacing(n-1)*2 + 146`. Connector column offset centers against the pair.
Connectors (1.5dp stroke): per round, `matchups.count/2` pairs merging cards `2i`,`2i+1`. Within a 36dp-wide pair: `pairHeight=146*2+spacing`, `topMid=73`, `bottomMid=146+spacing+73`, `centerY=pairHeight/2`, `midX=18`. Draw: `(0,topMid)→(midX,topMid)`, `(midX,topMid)→(midX,bottomMid)`, `(0,bottomMid)→(midX,bottomMid)`, `(midX,centerY)→(36,centerY)`. Base color `#404040`. Green accents (over gray) when a source advanced (`homeIsWinner||awayIsWinner`): top advanced → redraw its input in accent; bottom advanced → its input; either → output stub in accent.

## Stage matching helper
Exact match for "Final" (must NOT match "Cuartos de Final"); "Semifinal" also matches "Semifinales"; else case-insensitive normalized equality. Apply for both games and placeholders.

## Load / states
On appear load games response: `games = allGames`, `brackets = (brackets ?? []).sortedBy(position asc, nulls last)`, init selection once. Loading spinner ("Loading bracket…"/localize) + error state.

---

# 5. Top Stats — podium card + filtered full-leaderboard screen
*(iOS commit `3b83232`)*

## Overview
Player leaderboards grouped into stat categories. Keep the existing **horizontal carousel** (one page per category) + **page-indicator dots**. Changes: (1) each page redesigned into one dark card (title + podium + ranked list + footer link); (2) new full-leaderboard screen; (3) podium scores now plain white bold (was green glow); (4) `rank` field + new endpoint with `average` flag.

## Constants
Bg black `#000000`; accent `#A3FF12` (text on it black); primary white, secondary gray `#8E8E93`; card fill `#1A1A1A`; grays `#333333`/`#262626`/`#4D4D4D`/`#1F1F1F`/`#161616`. Radius small 8 / medium 12 / large 16 / xl 20. Spanish `es_MX`. pt→dp/sp 1:1.

## Data / API
Add optional `rank:Int` to player stat entry (null on `top_stats`, populated on full-list). Existing fields: `stat_short_name`, `stat_name` (machine key e.g. "points"), `score` (number OR numeric string — parse tolerantly to Double), `team_name`, `player_season_id`, nested `player` {first_name, last_name, picture nullable, fullName}.
New model **`TopStatDetail`**: `stat`, `stat_name`→statName, `stat_short_name`→statShortName, `average:Bool`, `players:[entry]` (carry rank).
New endpoint `GET {apiBase}/api/tournaments/{id}/top_stat.json?stat=<statKey>` — URL-encode; `<statKey>` = `category.stats.first.statName` (machine key). Returns `TopStatDetail`. Standard 2xx + error handling.

## Screen 1 — carousel category card
Carousel fills area between tournament header and floating bottom tab bar; each page scrolls vertically. Below: centered dots. Add **60dp bottom padding** so dots clear the tab bar.
**Dots:** row 6dp spacing; each capsule 8dp tall; active = 20dp wide accent; inactive = 8dp wide `#4D4D4D`; spring animate; 12dp vertical padding.

**Category page = one card** (fill `#1A1A1A`, radius 16dp, content stretches ≥ viewport height, top-aligned, 6dp H outer padding):
1. **Title** — `category.name`, centered, 18sp bold white, 12dp V padding; then full-width `#333333` divider.
2. **Podium** (only if ≥3 players) — horizontal row, bottom-aligned, 12dp spacing, order **#2 left / #1 center / #3 right**. Padding 16dp H, top 20dp, bottom 24dp; row inner 10dp T/B. Each column tappable → Player Detail.
   - #1 center: avatar 90dp, offset 0; **crown** above (angular 5-point, 28×20dp, accent), 6dp gap.
   - #2/#3: avatar 70dp, offset **down 20dp**, no crown.
   - Avatar: circular; load `player.picture` (http→as-is, else prefix `{apiBase}/`); fallback initials circle fill `#262626`, initials 30% of diameter bold `#666666` (first char first+last name).
   - Ring: rank 1 → accent 3dp; ranks 2/3 → `#4D4D4D` 2dp.
   - Rank badge: 24dp circle accent, number 12sp bold black, overlaps bottom-center (offset down 12dp).
   - Name: **first name only**, 14sp bold white, 1 line, 8dp top padding.
   - Team: `team_name`, 11sp regular `#808080`, 1 line.
   - Score: `formatScore`, **24sp heavy WHITE** (no shadow — changed from green glow).
   - **<3 players fallback:** skip podium; render top players as list rows numbered 1..N with `#262626` dividers (inset 16dp H), each → Player Detail.
3. **Ranked list** (rank 4…N, show ALL): preceded by full-width `#333333` divider. Rows zebra-striped: even rank bg `#1F1F1F`, odd `#161616`. Each → Player Detail.
   **List row (avatar 36dp):** row 12dp spacing, padding 12dp V / 16dp H, full width. Rank number 14sp semibold gray in 24dp box; circular avatar 36dp (plain, no ring); name (16sp bold white 1 line) + team (14sp gray 1 line, 2dp gap); spacer; score `formatScore` 18sp bold white.
4. **Footer link** (if any players): preceded by `#262626` divider inset 16dp H. Text **"Ver listado completo"** centered, 14sp semibold accent, 12dp V padding, tappable → Screen 2 passing tournament + `stat=category.stats.first.statName` + `categoryName=category.name`.

**Score format (Screen 1):** `tournament.usesAverage` → 1 decimal, else integer.

## Screen 2 — full leaderboard (`TopStatDetail`), NEW
Inputs: tournament, `stat` (machine key), `categoryName`. Black bg, edge-to-edge, default nav bar hidden.
**Header** (padding 16dp H, 12dp top, 8dp bottom): back button = 36dp circle white@8%, left chevron 14sp semibold white → back; centered title = `categoryName`, 20sp bold white, 1 line, shrink to 60%.
**States:** loading indicator; error + retry; empty (after filtering) = "person off" icon + **"No hay jugadores."** filling height.
**Content:** fixed **filter card** at top (doesn't scroll) + scrolling list below.

**Filter card** (fill `#1A1A1A`, radius 16dp, inner padding 16dp; outer 12dp H, 12dp top, 8dp bottom). Two groups 12dp apart, label+control 6dp:
1. **Buscar**: label 16sp semibold white; text input placeholder **"Nombre"**, 15sp white, padding 14dp H / 12dp V, fill `#1F1F1F`, radius 16dp, 1dp stroke `#4D4D4D`.
2. **Equipo**: label 16sp semibold white; dropdown styled same as field, shows selected team (15sp white 1 line) + down-chevron (13sp semibold gray). Options = **"Todos"** + distinct `team_name` sorted alphabetically. Default "Todos".

**Filtering (live, AND):** name — empty OR `fullName` contains search **case- AND diacritic-insensitive** (Android: `Normalizer` NFD + strip combining marks + lowercase, then contains). Team — "Todos" OR `team_name == selectedTeam`.

**List** (scrolling, below card): lazy vertical, 8dp row spacing, 12dp H padding, 12dp V. Each → Player Detail.
**Row (avatar 40dp, rounded dark card per row):** rank = **API `rank` verbatim** (don't renumber; null→0) 14sp semibold gray in 28dp box; circular avatar 40dp (initials 15sp bold on `#333333`); name (16sp bold white 1 line) + team (14sp gray 1 line, 2dp gap); spacer; score `formatScore` 20sp bold white.

**Score format (Screen 2):** use response `average` flag (`average ? 1-decimal : integer`); fall back to `tournament.usesAverage`.
Load: on create, `fetchTopStatDetail(tournamentId, stat)`; teams + filtered list derive from `players`.

## Navigation
Podium player / any list row (both screens) → Player Detail (entry + tournament id, existing). Footer → Screen 2.

## Tricky logic
Stat key (machine, endpoint) vs display name (title) — don't mix. Podium visual order #2/#1/#3, #1 largest. Rank source: Screen 1 by position, Screen 2 by API rank (don't renumber). Score format source differs per screen. Tolerant score parse. Accent-insensitive search. Zebra by rank parity (Screen 1) vs per-row cards (Screen 2). Podium score white (no glow). Keep carousel + dots; card fills viewport; 60dp bottom padding.
