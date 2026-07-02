# Bracket Visual Redesign — Design

**Date:** 2026-07-01
**Files:** `Brackets/BracketView.swift` only. No model or API changes.

**Depends on:** the `bracket-placeholders` branch (sticky header, per-bracket rendering,
`BracketMatchup.scheduledTime`/`venue`/placeholders). This builds on top of it.

## Goal

Restyle the playoff bracket to match the provided mockup: round headers as pill chips with a
date, redesigned matchup cards (circular avatars + team name + large score), winner
highlighting (green band/avatar/score, dimmed loser, neutral when unplayed), a per-card
clock + date + time footer with an optional venue Maps link, and connector segments that turn
green once a team advances.

## Colors / tokens (all in `BracketView.swift`)

- Card background: `Color(white: 0.09)`; corner radius 14.
- Round pill: fill `Color(white: 0.13)`, text `Color(white: 0.6)`, 11pt bold uppercase, tracking ~0.5.
- Header date: `Color(white: 0.4)`, 12pt.
- Winner: avatar fill `AppTheme.Colors.accent` + initials `AppTheme.Colors.accentText`; name `AppTheme.Colors.primaryText` bold; score `AppTheme.Colors.accent`; row band `AppTheme.Colors.accent.opacity(0.10)`.
- Neutral/loser: avatar fill `Color(white: 0.18)` + initials `Color(white: 0.5)`; name `Color(white: 0.55)`; score `Color(white: 0.5)`; unplayed score `"-"` `Color(white: 0.3)`.
- Footer: `Color(white: 0.4)`, 11pt, `clock` icon 10pt.
- Venue Maps link: `AppTheme.Colors.accent` + `mappin.and.ellipse` when coords; else `Color(white: 0.4)`.
- Connector: gray `Color(white: 0.25)`; advanced segment `AppTheme.Colors.accent`.

## 1. Round header (sticky) — pill + date

`bracketHeaders` (already sticky) renders, per non-last round, a **VStack**: a capsule pill with
the uppercased round name, and below it the round's date (`d MMM`, `es_MX` → `29 jun`). Column
width stays `matchupCardWidth` + trailing `connectorWidth`, left-aligned. The **Final** round's
inline title (in `roundColumn`, `isLastRound`) gets the same pill + date treatment.

**Round date** = the earliest `scheduledTime` among that round's matchups (games or
placeholders); nil if none (then no date line). Compute from `round.matchups` (and
`round.thirdPlace` for the final column).

## 2. Card container (`matchupCard`)

Dark rounded card (`Color(white: 0.09)`, radius 14). Keep the existing border logic (faint gray
default, `accent` for Final, red for live) and the live badge overlay. Keep the `NavigationLink`
wrapping for matchups with a real game (tap → detail). Uniform fixed height (see §7).

## 3. Team row (redesign) — avatar + name + score

Replace the current logo/name/score row. Each row (`padding` ~ H8/V6):
- **Avatar:** circle ~30pt with 2-letter initials. Winner → accent fill + black initials; else
  `Color(white: 0.18)` fill + `Color(white: 0.5)` initials. (No remote logo image — initials
  only, matching the mockup's circular monograms.)
- **Name:** middle, `frame(maxWidth: .infinity, alignment: .leading)`, `lineLimit(1)`,
  truncating. Winner → primaryText 14pt semibold; else `Color(white: 0.55)` 14pt.
- **Score:** right, ~20pt heavy. Winner → accent; loser → `Color(white: 0.5)`; unplayed → `"-"`
  `Color(white: 0.3)`. (Placeholder/seed rows use the seed label as the name and `"-"` score.)

## 4. Winner highlighting

Applied per row from the existing `homeIsWinner`/`awayIsWinner`. The winner row sits on a green
band (`RoundedRectangle` fill `accent.opacity(0.10)`, inset horizontally). When the matchup has
no winner (unplayed / seeds / TBD), **both** rows use the neutral style and no band.

## 5. Footer (per card)

Bottom of the card, shown when `scheduledTime != nil`:
- Line 1: `clock` icon + `d MMM · h:mm a` (`es_MX`, `apiTimeZone`, `amSymbol`/`pmSymbol` set to
  `"AM"`/`"PM"`) → `29 jun · 8:00 AM`, in `Color(white: 0.4)`.
- Line 2 (only when `venue != nil`): the venue — a Google-Maps link (accent + `mappin.and.ellipse`)
  when `venue.googleMapsURL != nil` (lat/lng present), else `Color(white: 0.4)` plain text.

This replaces the current date-on-top / venue-bottom split: date+time now sit together in the
footer (date before time), and the standalone top date line is removed.

## 6. Connectors — green accent for advanced

`connectorsColumn`/`connectorPair` take each source matchup's "has winner" state. For a pair
feeding one next-round slot, each input segment (and the shared vertical/output) is drawn
`AppTheme.Colors.accent` when its source matchup has a winner (that team advanced), else
`Color(white: 0.25)`. Thread a `[Bool]` (winner-present per matchup in the round) into
`connectorsColumn(roundIndex:matchCount:)` → `connectorPair`.

## 7. Layout / height

Bump `matchupCardHeight` (~140 → ~150; final value tuned in Xcode so two rows + footer fit
without clipping) and give the card an explicit fixed height (`alignment: .top` when a footer is
present, `.center` otherwise). `connectorPair`/`matchupSpacing`/`topPadding` derive from
`matchupCardHeight`, so the tree re-aligns automatically. Sticky-header horizontal-offset
behavior is unchanged.

## 8. Scope

- `BracketView.swift`: `bracketHeaders` pill+date + Final inline pill+date; `matchupCard`
  container + new team row (`teamRow`) + winner band; footer (clock+date+time + venue Maps link);
  `connectorsColumn`/`connectorPair` accent; `matchupCardHeight`; round-date + formatter helpers;
  `@Environment(\.openURL)` already present.
- Remove: the old square-logo `teamLogoView`/`logoPlaceholderWithInitials`/`placeholderLogo`
  usage in the row if replaced by the avatar (keep or delete as needed); the top date line added
  last turn; `matchupFooter` already replaced by `venueRow` — extend for date+time+clock.
- Unchanged: `GamePlaceholder`/models, `buildMatchup`/`buildRounds`/precedence, bracket tabs,
  navigation destinations, live refresh, other views.

## Out of scope

- No model/API changes. No new detail screen.
- No team logo images in the bracket (avatars are initials only, per the mockup).
- Bracket types/round sequence unchanged (octavos/quarterfinals/semifinals).
