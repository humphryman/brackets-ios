# Hide Suggested QF Teams Until Games Exist — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** In a quarterfinals-type bracket, render QF matchups without a scheduled game as TBD vs TBD instead of pulling seeded teams from standings.

**Architecture:** Single-line behavior change inside `buildQuarterfinalsBracket()`. The no-game `else` branch swaps its `teamA` / `teamB` fallbacks for `nil`, which causes the existing nil-aware `teamRow` rendering to display placeholder logos + `"TBD"`. The cascade through `buildRoundWithWinners` to SF and Final rounds is already correct — with nil winners, those rounds also render TBD.

**Tech Stack:** SwiftUI, Swift. No third-party deps.

**Project constraint:** No terminal build tools and no test target — verification is reading the file back, committing, and running the app in Xcode. Steps that would normally be `pytest` / `swift test` are replaced with file-read verification. Ignore SourceKit "Cannot find type X in scope" diagnostics — known indexing noise for sibling-file symbols in the same target.

**Spec:** `docs/superpowers/specs/2026-05-11-bracket-hide-suggested-qf-teams-design.md`

---

### Task 1: Replace seeded fallback teams with nil in QF no-game branch

**Files:**
- Modify: `Brackets/BracketView.swift` (`buildQuarterfinalsBracket()`, around lines 416–428)

- [ ] **Step 1: Apply the edit**

Open `Brackets/BracketView.swift`. Find the `else` branch inside `buildQuarterfinalsBracket()`. Current state:

```swift
            } else {
                // No game yet — show seeded teams without scores
                qfMatchups.append(BracketMatchup(
                    homeTeam: teamA,
                    homeScore: nil,
                    homeIsWinner: false,
                    awayTeam: teamB,
                    awayScore: nil,
                    awayIsWinner: false,
                    hasGame: false,
                    game: nil
                ))
            }
```

Replace with:

```swift
            } else {
                // No game yet — show empty TBD slots
                qfMatchups.append(BracketMatchup(
                    homeTeam: nil,
                    homeScore: nil,
                    homeIsWinner: false,
                    awayTeam: nil,
                    awayScore: nil,
                    awayIsWinner: false,
                    hasGame: false,
                    game: nil
                ))
            }
```

Only the `homeTeam` and `awayTeam` lines change. The comment is updated to reflect the new behavior. Do not touch the surrounding `for (seedA, seedB) in seedPairs` loop, the `teamFromSeed` calls, the `findGame` call, or the print statements above this branch — `teamA` / `teamB` must remain in scope because `findGame` uses them to look up matching games.

- [ ] **Step 2: Read the file back to verify**

Read `Brackets/BracketView.swift` lines 380–435. Confirm:

- The `else` branch passes `homeTeam: nil` and `awayTeam: nil`.
- The comment reads `// No game yet — show empty TBD slots`.
- Lines above the `else` (the `for (seedA, seedB) in seedPairs`, `teamFromSeed` calls at ~398–399, the `findGame` call at ~402, and the debug `print` at ~403) are unchanged.
- The `if let game = game { ... }` branch at lines ~405–415 (which appends a matchup with the real game's `homeTeam` / `awayTeam`) is unchanged.

- [ ] **Step 3: Commit**

```bash
git add Brackets/BracketView.swift
git commit -m "Hide suggested QF teams in bracket until games are scheduled"
```

- [ ] **Step 4: Manual Xcode verification**

This project has no test target. Open `Brackets.xcodeproj` in Xcode, build (⌘B), and run on a simulator. Navigate to a QF-type tournament on the Bracket tab and verify each scenario from the spec:

- **No QF games scheduled:** all 4 QF matchups show `?` placeholder logo + `"TBD"` on both sides. SF and Final rounds also show TBD slots. No team names from standings appear anywhere in the bracket.
- **Some QF games scheduled (e.g., 2 of 4):** the scheduled matchups show real teams and scores; the unscheduled matchups show TBD vs TBD. SF round shows the winners of completed QF games (if any are finished) and TBD for the rest.
- **All QF games scheduled:** behavior unchanged from before — all 4 matchups show their teams.
- **SF-type bracket:** behavior unchanged — first round still shows real games where they exist and TBD where they don't.

If any scenario does not match, return to Step 1 and re-check the edit. No commit is needed for this verification step unless tweaks are made.

---

## Self-review

**Spec coverage:**
- "Game exists for the seed pair → unchanged" — preserved by leaving the `if let game = game` branch untouched. ✓
- "No game exists → render two TBD slots" — Step 1 nil edit. ✓
- "SF and Final rounds also display TBD top to bottom when zero games scheduled" — automatic via `buildRoundWithWinners` with nil winners (no code change needed; verified in Step 4 scenario 1). ✓
- "`teamFromSeed` must remain because `findGame` keys on it" — Step 2 explicitly checks lines 398–399 are unchanged. ✓
- "Visual styling of TBD slots unchanged" — relies on existing `teamRow` / `placeholderLogo` rendering for nil teams. No styling code is touched. ✓
- "Semifinals-type bracket: no regression" — Step 4 scenario 4. ✓

**Placeholder scan:** No "TBD" / "TODO" / "appropriate" / "as needed" in the plan body. Code blocks are complete; the change is shown in full.

**Type consistency:** Only one property change (`homeTeam` / `awayTeam` from `Team?` to `nil` literal), no new symbols introduced. Nothing else to cross-reference.
