# Bracket Slot Placement via `bracket_id` Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Place bracket games into their stage slots strictly by the new `bracket_id` API field, propagate winners (and losers, for third-place) into empty slots, and render a Tercer Lugar card stacked under the Final.

**Architecture:** Two files change. `Game.swift` decodes a new optional `bracketId: Int?`. `BracketView.swift` is rewritten around a slot-based builder: for each stage and slot index, look up the game with matching `(stage, bracketId)`; if none, fill the slot from previous-round winners (or losers for Tercer Lugar). The old seed-based and team-id matching code is removed.

**Tech Stack:** Swift, SwiftUI. No third-party deps. No test target.

**Project constraint:** No terminal build tools and no test target — verification is reading the file back and running the app in Xcode. Steps that would normally be `swift test` are replaced with file-read verification. Ignore SourceKit "Cannot find type X in scope" diagnostics — known indexing noise for sibling-file symbols in the same target.

**Spec:** `docs/superpowers/specs/2026-05-11-bracket-id-slot-placement-design.md`

---

### Task 1: Decode `bracket_id` on `Game`

**Files:**
- Modify: `Brackets/Game.swift` (3 edit zones — struct property, CodingKeys, custom init)

- [ ] **Step 1: Add the property to the `Game` struct**

In `Brackets/Game.swift`, find the existing line:

```swift
    let stage: String?
```

Add immediately below it:

```swift
    let bracketId: Int?
```

So lines 13–14 become:

```swift
    let stage: String?
    let bracketId: Int?
```

- [ ] **Step 2: Add the CodingKey**

Find the `CodingKeys` enum (currently lines 83–91). It has:

```swift
        case stage
        case venue
```

Insert a new case between `stage` and `venue`:

```swift
        case stage
        case bracketId = "bracket_id"
        case venue
```

- [ ] **Step 3: Decode the field in the custom `init(from:)`**

Find the existing line (currently line 99):

```swift
        stage = try container.decodeIfPresent(String.self, forKey: .stage)
```

Add immediately below it:

```swift
        bracketId = try container.decodeIfPresent(Int.self, forKey: .bracketId)
```

- [ ] **Step 4: Read back the file to verify**

Read `Brackets/Game.swift` lines 10–115. Confirm:
- The `Game` struct has `let bracketId: Int?` right after `let stage: String?`.
- `CodingKeys` contains `case bracketId = "bracket_id"` between `case stage` and `case venue`.
- The `init(from:)` decodes `bracketId` with `decodeIfPresent` right after `stage`.
- No other lines changed (the other Game properties, computed properties, `TeamStat`, `Team`, `GameStatus`, `GamesResponse` are all untouched).

- [ ] **Step 5: Commit**

```bash
git add Brackets/Game.swift
git commit -m "Decode bracket_id on Game model"
```

---

### Task 2: Rewrite `BracketView` for slot-based placement + Tercer Lugar layout

**Files:**
- Modify: `Brackets/BracketView.swift` (multiple zones — see steps; one commit at the end)

This task is a single coherent rewrite of the bracket-building logic. Intermediate states between sub-steps will still compile cleanly (the new helpers coexist with the old until the final cleanup step).

- [ ] **Step 1: Update `BracketRound` to carry an optional Tercer Lugar matchup**

Find the existing `BracketRound` struct at the bottom of `Brackets/BracketView.swift`:

```swift
struct BracketRound: Identifiable {
    let name: String
    let matchups: [BracketMatchup]

    var id: String { name }
}
```

Replace with:

```swift
struct BracketRound: Identifiable {
    let name: String
    let matchups: [BracketMatchup]
    var thirdPlace: BracketMatchup? = nil

    var id: String { name }
}
```

- [ ] **Step 2: Add the new slot-based helper methods**

Inside `struct BracketView: View { ... }`, immediately above the existing `// MARK: - Build Rounds` line (currently around line 362), insert the following block of new helpers:

```swift
    // MARK: - Slot-Based Lookup

    private func stageMatches(gameStage: String, target: String) -> Bool {
        let g = gameStage.lowercased()
        let t = target.lowercased()
        if t == "final" { return g == "final" }
        if t == "semifinal" { return g == "semifinal" || g == "semifinales" }
        return g == t
    }

    private func gameForSlot(stage: String, slot: Int) -> Game? {
        games.first { game in
            guard let gameStage = game.stage,
                  stageMatches(gameStage: gameStage, target: stage) else { return false }
            return game.bracketId == slot
        }
    }

    private func winner(of matchup: BracketMatchup) -> Team? {
        if matchup.homeIsWinner { return matchup.homeTeam }
        if matchup.awayIsWinner { return matchup.awayTeam }
        return nil
    }

    private func loser(of matchup: BracketMatchup) -> Team? {
        if matchup.homeIsWinner { return matchup.awayTeam }
        if matchup.awayIsWinner { return matchup.homeTeam }
        return nil
    }

    /// For next-round slot `slotIndex` (0-based), source from previous matchups at
    /// indices slotIndex*2 and slotIndex*2 + 1. Returns home/away pair (winners or losers).
    private func propagatedPair(from previous: [BracketMatchup], slotIndex: Int, useLoser: Bool) -> (home: Team?, away: Team?) {
        let aIdx = slotIndex * 2
        let bIdx = aIdx + 1
        let a = aIdx < previous.count ? previous[aIdx] : nil
        let b = bIdx < previous.count ? previous[bIdx] : nil
        return (
            home: a.flatMap { useLoser ? loser(of: $0) : winner(of: $0) },
            away: b.flatMap { useLoser ? loser(of: $0) : winner(of: $0) }
        )
    }

    private func buildMatchup(stage: String, slot: Int, propagation: (home: Team?, away: Team?)?) -> BracketMatchup {
        if let game = gameForSlot(stage: stage, slot: slot) {
            return BracketMatchup(
                homeTeam: game.homeTeam,
                homeScore: game.homeScore,
                homeIsWinner: game.isFinished && game.winner?.id == game.homeTeam?.id,
                awayTeam: game.awayTeam,
                awayScore: game.awayScore,
                awayIsWinner: game.isFinished && game.winner?.id == game.awayTeam?.id,
                hasGame: true,
                game: game
            )
        }
        return BracketMatchup(
            homeTeam: propagation?.home,
            homeScore: nil,
            homeIsWinner: false,
            awayTeam: propagation?.away,
            awayScore: nil,
            awayIsWinner: false,
            hasGame: false,
            game: nil
        )
    }
```

- [ ] **Step 3: Replace `buildRounds()` with the new slot-based version**

Find the existing `buildRounds()` (currently lines ~364–381):

```swift
    private func buildRounds() -> [BracketRound] {
        let bracketType = tournament.bracketType?.lowercased() ?? ""

        switch bracketType {
        case "quarterfinals":
            return buildQuarterfinalsBracket()
        case "semifinals":
            return buildStageRounds([
                ("Semifinal", "Semifinal", 2),
                ("Final", "Final", 1)
            ])
        default:
            return buildStageRounds([
                ("Semifinal", "Semifinal", 2),
                ("Final", "Final", 1)
            ])
        }
    }
```

Replace with:

```swift
    private func buildRounds() -> [BracketRound] {
        let bracketType = tournament.bracketType?.lowercased() ?? ""

        var rounds: [BracketRound] = []
        var previous: [BracketMatchup] = []

        // QF round (only for quarterfinals-type tournaments)
        if bracketType == "quarterfinals" {
            let qfMatchups = (1...4).map { slot in
                buildMatchup(stage: "Cuartos de Final", slot: slot, propagation: nil)
            }
            rounds.append(BracketRound(name: "Cuartos de Final", matchups: qfMatchups))
            previous = qfMatchups
        }

        // SF round (always present)
        let sfMatchups = (1...2).map { slot -> BracketMatchup in
            let prop: (home: Team?, away: Team?)? = previous.isEmpty
                ? nil
                : propagatedPair(from: previous, slotIndex: slot - 1, useLoser: false)
            return buildMatchup(stage: "Semifinal", slot: slot, propagation: prop)
        }
        rounds.append(BracketRound(name: "Semifinal", matchups: sfMatchups))

        // Final + Tercer Lugar (combined column)
        let finalProp = propagatedPair(from: sfMatchups, slotIndex: 0, useLoser: false)
        let finalMatch = buildMatchup(stage: "Final", slot: 1, propagation: finalProp)

        let thirdProp = propagatedPair(from: sfMatchups, slotIndex: 0, useLoser: true)
        let thirdMatch = buildMatchup(stage: "Tercer Lugar", slot: 1, propagation: thirdProp)

        rounds.append(BracketRound(name: "Final", matchups: [finalMatch], thirdPlace: thirdMatch))

        return rounds
    }
```

- [ ] **Step 4: Update `roundColumn` to render Tercer Lugar under the Final**

Find the existing `roundColumn(round:roundIndex:)` (currently lines ~139–158):

```swift
    private func roundColumn(round: BracketRound, roundIndex: Int) -> some View {
        let topOffset = topPadding(for: roundIndex)
        let spacing = matchupSpacing(for: roundIndex)

        return HStack(alignment: .top, spacing: 0) {
            // Matchup cards
            VStack(spacing: spacing) {
                ForEach(Array(round.matchups.enumerated()), id: \.offset) { _, matchup in
                    matchupCard(matchup: matchup)
                }
            }
            .padding(.top, topOffset)

            // Connector lines to next round
            if roundIndex < rounds.count - 1 {
                connectorsColumn(roundIndex: roundIndex, matchCount: round.matchups.count / 2)
                    .padding(.top, topOffset)
            }
        }
    }
```

Replace with:

```swift
    private func roundColumn(round: BracketRound, roundIndex: Int) -> some View {
        let topOffset = topPadding(for: roundIndex)
        let spacing = matchupSpacing(for: roundIndex)

        return HStack(alignment: .top, spacing: 0) {
            // Matchup cards (+ Tercer Lugar stacked below, if present)
            VStack(spacing: spacing) {
                ForEach(Array(round.matchups.enumerated()), id: \.offset) { _, matchup in
                    matchupCard(matchup: matchup)
                }

                if let third = round.thirdPlace {
                    Spacer().frame(height: 16)
                    Text("3er Lugar")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color(white: 0.45))
                        .frame(width: matchupCardWidth, alignment: .center)
                    Spacer().frame(height: 6)
                    matchupCard(matchup: third)
                }
            }
            .padding(.top, topOffset)

            // Connector lines to next round
            if roundIndex < rounds.count - 1 {
                connectorsColumn(roundIndex: roundIndex, matchCount: round.matchups.count / 2)
                    .padding(.top, topOffset)
            }
        }
    }
```

- [ ] **Step 5: Change the empty-state guard**

Find the existing body guard (currently around line 29):

```swift
            } else if rounds.isEmpty {
                AppTheme.EmptyStateView(
                    icon: "square.grid.2x2",
                    message: "No hay bracket disponible."
                )
```

Replace with:

```swift
            } else if games.isEmpty {
                AppTheme.EmptyStateView(
                    icon: "square.grid.2x2",
                    message: "No hay bracket disponible."
                )
```

(Only the condition changes — `rounds.isEmpty` → `games.isEmpty`. The new builder always produces non-empty `rounds` once games are loaded, so the old guard would never fire.)

- [ ] **Step 6: Simplify `loadGames` (drop standings fetch)**

Find the existing `loadGames` (currently lines ~613–638):

```swift
    private func loadGames() async {
        isLoading = true
        errorMessage = nil

        do {
            async let gamesRequest = APIService.shared.fetchGamesResponse(for: tournament.id)
            async let standingsRequest = APIService.shared.fetchStandings(for: tournament.id)

            let response = try await gamesRequest
            games = response.allGames

            let standingsResult = try await standingsRequest
            switch standingsResult {
            case .flat(let s):
                standings = s
            case .groups(let groups):
                // Combine all group standings into a flat list sorted by total points
                standings = groups.flatMap(\.standings).sorted { $0.total > $1.total }
            }

            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
```

Replace with:

```swift
    private func loadGames() async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await APIService.shared.fetchGamesResponse(for: tournament.id)
            games = response.allGames
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
```

- [ ] **Step 7: Delete the now-unused state property**

Find the existing declaration (currently around line 11):

```swift
    @State private var standings: [TeamStanding] = []
```

Delete this entire line.

- [ ] **Step 8: Delete unused helper functions**

Delete the following functions in their entirety from `Brackets/BracketView.swift`:

1. `buildQuarterfinalsBracket()` — currently lines ~384–452.
2. `buildRoundWithWinners(stage:name:expectedMatchups:previousMatchups:)` — currently lines ~455–521.
3. `teamFromSeed(_:)` — currently lines ~524–528.
4. `findGame(teamA:teamB:in:)` — currently lines ~531–549.
5. `gamesForStage(_:)` — currently lines ~552–564.
6. `buildStageRounds(_:)` — currently lines ~567–609.

After deletion, the `// MARK: - Build Rounds` section should contain only the new `buildRounds()` from Step 3 and the new `// MARK: - Slot-Based Lookup` block from Step 2.

- [ ] **Step 9: Read back the file end-to-end**

Read `Brackets/BracketView.swift` in full. Confirm:

- `BracketRound` has the new `thirdPlace: BracketMatchup? = nil` field.
- The new helper block `stageMatches`, `gameForSlot`, `winner(of:)`, `loser(of:)`, `propagatedPair(...)`, `buildMatchup(...)` is present.
- `buildRounds()` matches Step 3 exactly.
- `roundColumn(...)` includes the Tercer Lugar rendering block.
- The empty-state guard uses `games.isEmpty`.
- `loadGames()` fetches only games (no standings).
- `@State private var standings: [TeamStanding] = []` is gone.
- All six deleted functions are gone (`buildQuarterfinalsBracket`, `buildRoundWithWinners`, `teamFromSeed`, `findGame`, `gamesForStage`, `buildStageRounds`).
- No references to deleted symbols remain anywhere in the file. (Search the file for the strings `teamFromSeed`, `findGame`, `gamesForStage`, `buildStageRounds`, `buildQuarterfinalsBracket`, `buildRoundWithWinners`, and `standings` — there should be zero matches outside of any comments.)
- The unrelated parts of the file (layout constants, pager, bracket content, matchup card, team rows, logo views, connector drawing, models) are unchanged.

- [ ] **Step 10: Commit**

```bash
git add Brackets/BracketView.swift
git commit -m "Place bracket games by bracket_id and add Tercer Lugar slot"
```

---

### Task 3: Manual Xcode verification

**Files:** No code changes. Manual verification only.

This project has no test target — verification is on a real simulator/device against staging data.

- [ ] **Step 1: Open the project in Xcode**

```bash
open /Users/humberto/Documents/Code/ios/Brackets/Brackets.xcodeproj
```

- [ ] **Step 2: Build (⌘B)**

Expected: build succeeds. If there are compile errors, return to Task 2 — most likely a missed deletion (an old function still references `standings`, `teamFromSeed`, etc.).

- [ ] **Step 3: Verify each acceptance scenario from the spec**

Run on a simulator and check:

1. **QF tournament with `bracket_id` on all games** — matchups appear in the slots the API assigns. Confirm the team displayed in slot 1 of QF matches whatever team is in the game with `stage = "Cuartos de Final"`, `bracket_id = 1`.
2. **QF tournament with zero scheduled games** — every slot reads TBD. Bracket structure (QF | SF | Final + Tercer Lugar) still renders.
3. **QF tournament mid-progress** (all QF done, SF not scheduled) — QF cards show real teams/scores. SF slots show the QF winners as propagated text. Final/Tercer Lugar still TBD.
4. **SF-type tournament** — only SF and Final columns. Tercer Lugar still appears under the Final.
5. **Tournament with a `"Tercer Lugar"` game** — that game's data appears in the Tercer Lugar card under the Final.
6. **Tournament without a `"Tercer Lugar"` game** — Tercer Lugar slot shows TBD or propagated losers, depending on SF state.
7. **Legacy tournament (no `bracket_id` on any games)** — bracket renders structurally with all TBDs. No crash.
8. **Tap a slot with a real game** — pushes `GameResultView` (finished) or `UpcomingGameView` (upcoming).
9. **Tap a propagated or TBD slot** — does nothing (no nav link). Confirm no errors in the console.

If any scenario fails, return to the relevant step in Task 2.

- [ ] **Step 4: No commit needed (verification only).** Commit only if tweaks were made.

---

## Self-review

**Spec coverage:**

- `bracket_id` decoded on `Game` → Task 1. ✓
- Strict slot placement with TBD fallback → Task 2 Step 2 (`gameForSlot`) + Step 3 (`buildRounds`) + Step 2 (`buildMatchup`). ✓
- Propagation (QF→SF winners, SF→Final winners, SF→Tercer Lugar losers) → Task 2 Step 2 (`propagatedPair`) + Step 3 (`buildRounds`). ✓
- Layout: round columns unchanged, Final column stacks Final + "3er Lugar" + Tercer Lugar → Task 2 Step 4 (`roundColumn`). ✓
- Empty state: `games.isEmpty` → Task 2 Step 5. ✓
- Code removal (six functions + standings state + standings fetch) → Task 2 Steps 6–8. ✓
- Spec acceptance scenarios all verifiable → Task 3 Step 3. ✓

**Placeholder scan:** No "TBD" / "TODO" / "appropriate" / "as needed" / "etc." in the plan body. The user-visible string `"TBD"` in the rendered UI is the displayed label, not a placeholder in the plan.

**Type consistency:** `BracketMatchup` (unchanged), `BracketRound` (gains `thirdPlace`), `Team`, `Game`, `BracketView`'s `games` / `tournament` properties all referenced consistently. New helper signatures match between Step 2 (definition) and Step 3 (use).
