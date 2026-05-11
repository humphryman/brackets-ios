# Hide suggested QF teams until games exist — design

**Date:** 2026-05-11
**Status:** Approved for implementation
**Scope:** iOS app (`Brackets`), `BracketView.swift`

## Problem

For tournaments with `bracketType == "quarterfinals"`, the QF round currently shows seeded teams (1v8, 4v5, 2v7, 3v6) pulled from standings even when no game has been scheduled for that matchup. These "suggested teams" can mislead users into thinking a matchup has been set when it hasn't.

The SF bracket type's first round already does the right thing: empty TBD slots when no game exists.

## Behavior change

In a QF-type bracket, the **initial (QF) round** is rendered per matchup:

- **Game exists for the seed pair** → render the matchup using the game's actual `homeTeam` / `awayTeam` (and scores if finished). No change from current behavior.
- **No game exists** → render two TBD slots (placeholder logo + `"TBD"` label). Do NOT pull seeded teams from standings.

The SF and Final rounds in a QF bracket already propagate winners from previous matchups via `buildRoundWithWinners`. With zero games on the schedule, all QF matchups have `homeIsWinner = false` / `awayIsWinner = false`, so the propagation yields all-nil winners — meaning SF and Final rounds also display TBD top to bottom. As soon as one QF game is scheduled, that single matchup populates with real teams; the rest remain TBD. This cascade is the intended behavior.

## Out of scope

- The SF bracket type. Its first round already does not show suggested teams. No change.
- The `teamFromSeed(_:)` helper. It is still used by `findGame(teamA:teamB:in:)` to key lookups, so it must remain.
- Visual styling of TBD slots. The existing `teamRow` / `placeholderLogo` rendering already handles nil teams correctly — no UI changes.
- Stage tabs other than Bracket.

## Implementation summary

Single edit in `Brackets/BracketView.swift`, `buildQuarterfinalsBracket()`. In the `else` branch (currently lines 416–428), replace `homeTeam: teamA` and `awayTeam: teamB` with `homeTeam: nil` and `awayTeam: nil`. Everything else in the matchup constructor stays unchanged (`hasGame: false`, `game: nil`, scores `nil`, winners `false`).

The diff is ~2 effective lines.

## Acceptance

- A QF tournament with **zero** QF games on the schedule renders all 4 QF matchups as TBD vs TBD, and SF/Final rounds also as TBD.
- A QF tournament with **some** QF games (e.g., 2 of 4) renders those 2 matchups with real teams/scores and the remaining 2 as TBD vs TBD.
- A QF tournament with **all** QF games scheduled renders all 4 matchups with real teams (unchanged behavior).
- Seed lookups for `findGame` still work — when a QF game's teams match a seed pair (by id or name), it pairs correctly into the right matchup position.
- No regression in semifinals-type bracket rendering.
