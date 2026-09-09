# Android Port — iOS Changes from 2026-09-07

Detailed, self-contained implementation prompts for porting today's iOS ("Brackets") changes to the Android app. Each section is written to be stack-agnostic — adapt to Jetpack Compose or XML Views. iOS point sizes map 1:1 to Android `dp`/`sp`.

**Source map** — these landed as working-tree changes on branch `navigation_fixes` (on top of `d1c7a33`), not as separate commits:

| Change | iOS files |
|--------|-----------|
| Athlete name shortening (app-wide) | new `Brackets/PlayerName.swift` + 10 view/share files |
| Score typography — Games card | `Brackets/GamesListView.swift` (`CenterSection`) |
| Score typography + "Final" label — Result screen | `Brackets/GameResultView.swift` |
| League card sport badge → design-system Badge | `Brackets/LeagueSelectionView.swift` |
| Stats podium first-place glow | `Brackets/StatsLeadersView.swift` (`GoldGlow`) |

**Suggested order:** §1 is the largest and riskiest (many files, subtle logic) — do it on its own branch and lean on the test table. §2 and §3 are independent of §1 and of each other.

> **Tokens used below:** accent lime (`#C7F24A` in the design docs / `#A3FF12` in iOS code — use whichever your app already defines as the accent), black `#000000` on accent, `gray400` = `#9CA3AF`. Type face for numerals and titles is **Barlow Condensed** (bundled, SIL OFL).

---

# 1. Athlete names — one given name, one surname

## Context
Rosters store full legal names — first name `"Juan Carlos"`, last name `"Reyes Peña"`. Everywhere the app shows an athlete, it must display only **the first given name and the first surname**: `"Juan Reyes"`. This keeps names on one line and reads the way players are actually called.

## Where the rule lives
Put it in **one shared helper** (iOS: `PlayerName`) in the model/util layer. Every screen reads through it — do **not** shorten inline at call sites. Expose extension properties (`shortFirstName`, `shortLastName`, `shortName`, `initials`) on each model that carries a name from the API, so views never touch the raw fields again.

## Algorithm
Take the first name out of a multi-word string:

```
words = name.split(whitespace)          // collapses double/leading/trailing spaces
kept  = []
i     = 0

while i < words.size:
    word = words[i]; kept += word; i++
    if isParticle(word): continue                     // a particle is never the end of a name
    if i < words.size && isLinker(words[i]): continue  // a linker joins this name to the next word
    break

// generational suffix — it belongs to the person, so carry it
rest = words.drop(kept.size)
if      rest.first is suffix: kept += rest.first      // "Pérez Jr Gómez"
else if rest.last  is suffix: kept += rest.last       // "Pérez Gómez Jr"

return kept.join(" ")
```

`shortName = [first(firstName), first(lastName)].filter { it.isNotEmpty() }.join(" ")`

## The three word sets
All matched **lowercased and accent-insensitive**.

- **linkers** — glue in any position, whether opening a name or joining its halves:
  `de, del, la, las, le, los, el, da, das, do, dos, di, della, du, van, von, der, den, ten, ter`
- **openers** — only ever *start* a name; unlike a linker, one of these never pulls itself onto the name before it:
  `san, santa, st`
- **suffixes** — matched with any trailing `.` or `,` stripped, so `Jr`, `Jr.`, `JR`, `Jr,` all hit:
  `jr, sr, junior, senior, ii, iii, iv, v`

`isParticle(w)` = linker **or** opener. `isLinker(w)` = linker only.

**Why the linker/opener split matters.** `"Martin del Campo Guzman"` starts with a non-particle, so a naive "only strip leading particles" rule stops at `"Martin"` — that was a real bug on iOS. Continuing while the *next* word is a linker fixes it. But applying the same to openers would break `"López San Miguel"`, which is two surnames whose first is `"López"` — while `"San Miguel Pérez"` is one surname, *San Miguel*.

**Do not include `y` / `e`.** In `"García y López"` the `y` formally joins two separate surnames, so it must shorten to `"García"`.

## Initials
Avatar fallbacks come from the same helper so they always match the name shown: filter out particles **and** suffixes, then take the first letter of the first and the last remaining word. If only one word survives, use its first two letters.

## Test table
Add unit tests for exactly this (stored first name · stored last name → shown, initials):

| stored | shown | initials |
|---|---|---|
| Enrique · Martin del Campo Guzman | Enrique Martin del Campo | EC |
| Juan Carlos · Reyes Peña | Juan Reyes | JR |
| Pablo · de la Cruz Peña | Pablo de la Cruz | PC |
| José · de los Santos Villa | José de los Santos | JS |
| Luis · López San Miguel | Luis López | LL |
| Luis · San Miguel Pérez | Luis San Miguel | LM |
| Luis Manuel · Pérez Jr | Luis Pérez Jr | LP |
| Luis · Pérez Gómez Jr | Luis Pérez Jr | LP |
| Luis · Martin del Campo Jr | Luis Martin del Campo Jr | LC |
| Ana · García y López | Ana García | AG |
| Robert · Smith III | Robert Smith III | RS |
| Miguel · Santa Cruz Sr. | Miguel Santa Cruz Sr. | MC |
| *(empty)* · Solo | Solo | SO |
| Ana · *(empty)* | Ana | AN |
| `"  Ana  Sofía "` · `"  Ruiz   Vega  "` | Ana Ruiz | AR |

Preserve the stored casing — if the API says `"JR"`, render `"JR"`; do not normalize to `"Jr."`.

## Surfaces to update
Stats leaders (podium **and** list), full stat leaderboard, team roster, team stat leaders, athlete profile header, player-of-the-game card, game result stat tables and leaders, live game tables, upcoming game rosters, the player game-stats sheet, **every avatar initials fallback**, and the **shareable / Instagram images**.

For the share cards, shorten **once where the share model is built**, so every card design inherits it without each card trimming again.

## Exception
Player **search** keeps matching against the full stored name, so typing a second surname still finds the player even though it isn't displayed.

## Also
If any sample/preview data uses long multi-part names, shorten it so previews reflect what actually ships.

---

# 2. Score typography + design-system cleanup

Four small consistency fixes. They are independent; do them in one pass.

## 2.1 Game card score — Games screen
The finished-game score on the game list card ("41 - 52") uses the system font at **24sp bold**. Switch it to **Barlow Condensed semibold at 32sp**.

Barlow Condensed reads narrower and optically smaller than the system font at the same point size, so the larger size keeps the same visual weight — this is the same 24 → 32 step the app already took for screen headers. Pull the size into a named constant with a short comment explaining why it is larger.

Leave the `-` separator in the system font at its current size (18sp). **Do not** change the live game card's score (system 28sp heavy with the pulse animation) — it is a deliberately distinct treatment.

## 2.2 Result screen score
Same change to the big score inside the bordered score box on the game result ("Resultado") screen: **Barlow Condensed semibold at 32sp**, replacing system 24sp bold. Winner/loser colors are unchanged (winner in accent, loser in secondary text).

## 2.3 "Final" label
The small `Final` label under that score box uses an ad-hoc gray (a raw ~40% white). Replace it with the design-system **`gray400`** token (`#9CA3AF`). Font and size unchanged (11sp semibold).

## 2.4 Sport badge — league selection screen
On the league selection screen ("Ligas Activas" / "Ligas Pasadas"), the `BASKETBALL` pill on the league cards is hand-rolled inline: a capsule filled with the accent color, black bold 11sp label, 10/5 padding.

Replace **every occurrence** with the shared design-system **Badge** component in its **lime** style (solid lime fill, black label — the Figma default). The component brings its own geometry — 12/6 padding, 10sp semibold, single-line label that never ellipsizes — so drop all the inline styling.

There is more than one copy of this badge on that screen (the active-league card and a second card variant); replace them all. While you are there, check for other hand-rolled sport badges. Leave buttons ("Ver categoría") and live indicators alone — those are not badges.

---

# 3. Stats podium — first-place gold glow

## Context
On the Stats screen, first place on the podium has a soft gold halo behind the athlete's photo: two offset radial gradients that drift against each other so the light shifts instead of just pulsing.

## 3.1 Delayed entrance
The glow must **not** be lit when the screen appears. It waits **1.5 seconds**, then fades in over ~0.7s (ease-out) with a small scale pop (~0.82 → 1.0), so the podium is read first and the light then arrives on the winner. Put the delay in a named constant.

## 3.2 More visible, more animated
- Inner halo opacity **0.55 → 0.78**; outer halo **0.30 → 0.44**.
- Widen the counter-drift so the two layers clearly move against each other: inner `1.12 ↔ 0.88`, outer `0.90 ↔ 1.18` (was roughly ±0.07 on both).
- Breathing cycle **3.2s → 2.4s**, ease-in-out, repeating forever with autoreverse.
- The breath also pulses overall brightness **0.78 → 1.0**. Keep this on its **own animated value**, separate from the entrance fade — if both animations drive the same opacity property, the repeating animation captures the fade-in and the entrance looks wrong. (iOS stacks two opacity modifiers; on Compose use two separate animated floats multiplied, or two nested alpha layers.)

## 3.3 Restart when returning from the athlete profile
Tapping a podium athlete opens the "Perfil del Atleta" screen/sheet. When the user comes back to Stats, the entrance must **replay**: reset to dark, wait the 1.5s again, then fade in.

The podium is typically **not** destroyed while the profile covers it, so a plain "run once on first composition" effect fires only once. Drive it off an explicit **restart key** that changes when the profile is dismissed (iOS increments a counter when the sheet route goes back to `null` and keys the animation task on it) — or off a resume/visibility signal if that is more idiomatic on your side.

Reset the animated values **without animation** before waiting, so a restart never flashes the previous lit state.

## 3.4 Verify only — shared-element backdrop artifact (iOS-specific bug)
On iOS, the zoom/shared-element transition into the athlete profile was drawing its **default source backdrop** — an opaque rounded card with a shadow — behind the round podium photo. It flashed as a visible square while the sheet opened and closed. The stat list rows hid it because they have their own opaque background; the podium sits directly on the screen background, so it showed.

If Android uses a shared-element transition here, check for the equivalent artifact. The fix is to make the transition source's backdrop transparent (no container color, no shadow) **without** changing the zoom geometry — the sheet must still grow out of and collapse back into the athlete's photo. If Android has no such backdrop, nothing to do.
