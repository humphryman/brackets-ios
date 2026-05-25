# Live Game End Auto-Refresh Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When a polled live game finishes, the Games tab refetches `/games.json` and the live game detail screen swaps to `GameResultView` in place — both within ≤5s of the server marking the game finished.

**Architecture:** A single detection signal — `GameDetail.isFinished` (any `teamStats.result != nil`) — drives both views. In `GamesListView`, the existing per-game live-detail polling loop sets a flag when any polled detail shows the game has finished, then calls `loadGames()` once after the loop and stops the live-refresh timer if no live games remain. In `LiveGameDetailView`, the polling callback sets a new `@State endedGame: Game?` (built from `(originalGame, latestDetail)`); the body conditionally renders `GameResultView(...)` once `endedGame` is non-nil. `GameResultView` already drives its own header and data fetch, so the navigation stack is unchanged.

**Tech Stack:** Swift, SwiftUI (iOS 17+). No third-party deps. No test target.

**Project constraint:** No terminal build tools and no test target — verification is reading each modified file back and running the app in Xcode against staging data with a live game. There are no `swift test` steps. Ignore SourceKit "Cannot find type X in scope" diagnostics on sibling-file symbols — known indexing noise in this project.

**Spec:** `docs/superpowers/specs/2026-05-25-live-game-end-auto-refresh-design.md`

---

### Task 1: Add `GameDetail.isFinished` extension

**Files:**
- Modify: `Brackets/GameDetail.swift` (one edit zone — new extension placed after the existing `GameDetail: Codable` extension)

The existing `GameDetail` struct and its `Codable` extension occupy roughly lines 81–128. The next type in the file is `Venue` at line 132. Insert the new extension between them.

- [ ] **Step 1: Add the `isFinished` extension**

In `Brackets/GameDetail.swift`, find the closing `}` of the `GameDetail: Codable` extension (currently line 128). On the next blank line before `// MARK: - Venue` (currently line 130), insert:

```swift
extension GameDetail {
    var isFinished: Bool {
        teamStats?.contains { $0.result != nil } ?? false
    }
}

```

The result should read:

```swift
        playerOfTheGame = try? container.decodeIfPresent(PlayerOfTheGame.self, forKey: .playerOfTheGame)
    }
}

extension GameDetail {
    var isFinished: Bool {
        teamStats?.contains { $0.result != nil } ?? false
    }
}

// MARK: - Venue
```

- [ ] **Step 2: Read back the file to verify**

Read `Brackets/GameDetail.swift` lines 100–140. Confirm:

- The new `extension GameDetail { var isFinished: Bool { ... } }` sits between the closing `}` of `extension GameDetail: Codable` and the `// MARK: - Venue` marker.
- The body is exactly `teamStats?.contains { $0.result != nil } ?? false`.
- No other lines changed (the `Codable` extension above, the `Venue` struct below, and everything else in the file are unchanged).

- [ ] **Step 3: Commit**

```bash
git add Brackets/GameDetail.swift
git commit -m "Add GameDetail.isFinished helper"
```

---

### Task 2: Auto-swap `LiveGameDetailView` to `GameResultView` on game end

**Files:**
- Modify: `Brackets/LiveGameDetailView.swift` (four edit zones — initializer parameter, new state, new helper, `loadGameDetail()` body, top-level `body` wrapper)

- [ ] **Step 1: Add `tournamentName` initializer parameter**

Find the existing property declarations at the top of `struct LiveGameDetailView` (currently lines 9–11):

```swift
    let game: Game
    let tournamentId: Int
    @Environment(\.dismiss) private var dismiss
```

Insert a new line between `let tournamentId: Int` and `@Environment(\.dismiss)` so the block becomes:

```swift
    let game: Game
    let tournamentId: Int
    var tournamentName: String? = nil
    @Environment(\.dismiss) private var dismiss
```

- [ ] **Step 2: Add the `endedGame` state property**

Find the existing `@State` declarations (currently lines 13–23). The last existing state line is:

```swift
    @State private var rosterGlowRed: Set<Int> = [] // players moved to bench
```

Add immediately below it:

```swift
    @State private var endedGame: Game?
```

- [ ] **Step 3: Add the `makeEndedGame(from:)` helper**

Find the `// MARK: - Data Loading` section header (currently line 96). Immediately above it (after the closing `}` of `body` on line 94), insert a new MARK section + helper. The resulting block:

```swift
        .onDisappear {
            stopRefreshTimer()
        }
    }

    // MARK: - Game End Transition

    private func makeEndedGame(from detail: GameDetail) -> Game {
        Game(
            id: detail.id,
            gameTime: detail.gameTime ?? game.gameTime,
            stage: detail.stage ?? game.stage,
            bracketId: game.bracketId,
            venue: detail.venue ?? game.venue,
            isLive: false,
            period: nil,
            teamStats: detail.teamStats?.map { stat in
                TeamStat(
                    id: stat.id,
                    score: stat.score,
                    result: stat.result,
                    teamName: stat.teamName,
                    teamLogo: stat.teamLogo
                )
            }
        )
    }

    // MARK: - Data Loading
```

Note: `Game`'s synthesized memberwise initializer is available because `Game` declares its custom `init(from decoder:)` in an `extension` (`Brackets/Game.swift:96-115`), which does not suppress the synthesized memberwise init. Same for `TeamStat` (no custom init defined at all).

- [ ] **Step 4: Update `loadGameDetail()` to detect game-end and populate `endedGame`**

Find the existing `loadGameDetail()` (currently lines 98–122). The successful-fetch block is:

```swift
            let detail = try await APIService.shared.fetchGameDetail(
                tournamentId: tournamentId,
                gameId: game.id
            )
            await MainActor.run {
                detectStatChanges(newDetail: detail)
                gameDetail = detail
                isLoading = false
            }
```

Replace the `await MainActor.run { ... }` block with:

```swift
            await MainActor.run {
                detectStatChanges(newDetail: detail)
                gameDetail = detail
                isLoading = false
                if detail.game.isFinished {
                    stopRefreshTimer()
                    endedGame = makeEndedGame(from: detail.game)
                }
            }
```

Only the `await MainActor.run` body changes — the surrounding `do { ... } catch { ... }` and the rest of `loadGameDetail()` stay untouched.

- [ ] **Step 5: Wrap the top-level `body` in a conditional swap**

Find the existing `body` declaration (currently line 25):

```swift
    var body: some View {
        ZStack {
            AppTheme.Colors.background
                .ignoresSafeArea()
            // ... rest of the existing body ...
        }
        .navigationBarHidden(true)
        .task {
            await loadGameDetail()
            startRefreshTimer()
        }
        .onDisappear {
            stopRefreshTimer()
        }
    }
```

Wrap the existing `ZStack { ... }` block (and its `.navigationBarHidden`, `.task`, `.onDisappear` modifiers) inside an `if let` conditional, so the new `body` reads:

```swift
    var body: some View {
        if let endedGame {
            GameResultView(
                game: endedGame,
                tournamentId: tournamentId,
                tournamentName: tournamentName
            )
        } else {
            ZStack {
                AppTheme.Colors.background
                    .ignoresSafeArea()
                // ... rest of the existing ZStack body unchanged ...
            }
            .navigationBarHidden(true)
            .task {
                await loadGameDetail()
                startRefreshTimer()
            }
            .onDisappear {
                stopRefreshTimer()
            }
        }
    }
```

**Do not modify any code inside the `ZStack`.** The transformation is purely a wrap. The existing header, content sections, MARKs, helpers, and modifiers (`navigationBarHidden`, `task`, `onDisappear`) all stay verbatim, just indented one extra level inside the `else` branch.

Hint: an easy way to do this without re-indenting line by line is to:
1. Type the `if let endedGame { GameResultView(...) } else {` line and the closing `}` around the existing `ZStack { ... }.onDisappear { ... }` block.
2. Let Swift's formatter or Xcode re-indent the wrapped block.

`body` must return exactly one view per branch — both branches above do.

- [ ] **Step 6: Read back the file end-to-end**

Read `Brackets/LiveGameDetailView.swift` in full. Confirm:

- `LiveGameDetailView` has the new `var tournamentName: String? = nil` between `tournamentId` and `@Environment(\.dismiss)`.
- `@State private var endedGame: Game?` is present, immediately after `rosterGlowRed`.
- A `// MARK: - Game End Transition` section + `makeEndedGame(from:)` helper exists between `body` and `// MARK: - Data Loading`.
- `loadGameDetail()` `await MainActor.run { ... }` block now contains the `if detail.game.isFinished { stopRefreshTimer(); endedGame = makeEndedGame(from: detail.game) }` clause.
- `body` is now `if let endedGame { GameResultView(...) } else { ZStack { ... }... }` — with the entire existing ZStack-and-modifiers chain inside the `else` branch.
- No symbol referenced in the new code is undefined (`GameResultView`, `Game`, `TeamStat`, `detail.game.isFinished`, `stopRefreshTimer`, `tournamentName` all exist in the appropriate places).
- The rest of the file (`detectStatChanges`, `livePlayerStatsCard`, `liveStatsTable`, `rowBackground`, `rosterGlowColor`, `livePlayerRow`, `livePlayerAvatar`, `livePlayerInitials`) is unchanged.

- [ ] **Step 7: Commit**

```bash
git add Brackets/LiveGameDetailView.swift
git commit -m "Swap LiveGameDetailView to GameResultView when game ends"
```

---

### Task 3: Detect game-end during `GamesListView` live polling and refetch games

**Files:**
- Modify: `Brackets/GamesListView.swift` (two edit zones — `refreshLiveGames()` body, `LiveGameDetailView` call site)

- [ ] **Step 1: Update `refreshLiveGames()` to track game-end and refetch**

Find the existing `refreshLiveGames()` (currently lines 205–220):

```swift
    private func refreshLiveGames() async {
        guard let games = gamesResponse?.allGames.filter({ $0.isLive }) else { return }
        for game in games {
            do {
                let detail = try await APIService.shared.fetchGameDetail(
                    tournamentId: tournament.id,
                    gameId: game.id
                )
                await MainActor.run {
                    liveGameDetails[game.id] = detail
                }
            } catch {
                print("❌ Live game refresh error for game \(game.id): \(error)")
            }
        }
    }
```

Replace with:

```swift
    private func refreshLiveGames() async {
        guard let games = gamesResponse?.allGames.filter({ $0.isLive }) else { return }

        var anyEnded = false
        for game in games {
            do {
                let detail = try await APIService.shared.fetchGameDetail(
                    tournamentId: tournament.id,
                    gameId: game.id
                )
                await MainActor.run {
                    liveGameDetails[game.id] = detail
                }
                if detail.game.isFinished {
                    anyEnded = true
                }
            } catch {
                print("❌ Live game refresh error for game \(game.id): \(error)")
            }
        }

        if anyEnded {
            await loadGames()
            if !hasLiveGames {
                await MainActor.run { stopLiveRefresh() }
            }
        }
    }
```

Notes:
- `loadGames()` is already declared `async` on line 222 — no signature change needed.
- `hasLiveGames` is a computed property over `gamesResponse?.allGames` (line 35–37). After `await loadGames()` updates `gamesResponse`, reading `hasLiveGames` reflects the fresh state.
- `stopLiveRefresh()` invalidates the `liveRefreshTimer`. Wrapping it in `MainActor.run` is defensive — `Timer.invalidate()` is documented main-thread-only.

- [ ] **Step 2: Pass `tournament.name` to `LiveGameDetailView` at the call site**

Find the `LiveGameDetailView` constructor call inside the `ForEach` loop (currently line 129):

```swift
                                                if game.isLive {
                                                    NavigationLink {
                                                        LiveGameDetailView(game: game, tournamentId: tournament.id)
                                                    } label: {
```

Replace the inner line with:

```swift
                                                        LiveGameDetailView(game: game, tournamentId: tournament.id, tournamentName: tournament.name)
```

Only the constructor call changes — the surrounding `NavigationLink`, `if game.isLive { ... }`, and `label:` are unchanged.

- [ ] **Step 3: Read back the file to verify**

Read `Brackets/GamesListView.swift`. Confirm:

- `refreshLiveGames()` declares `var anyEnded = false` at the top, sets it inside the loop when `detail.game.isFinished`, and at the end does `if anyEnded { await loadGames(); if !hasLiveGames { await MainActor.run { stopLiveRefresh() } } }`.
- The `LiveGameDetailView` call on what was line 129 now reads `LiveGameDetailView(game: game, tournamentId: tournament.id, tournamentName: tournament.name)`.
- No other parts of the file changed: `body`, `availableFilters`, `filteredGames`, `hasLiveGames`, `startLiveRefreshIfNeeded`, `stopLiveRefresh`, `loadGames`, `scrollToInitialPosition`, `formatDateHeader`, and all sub-views below (`GameFilterView`, `LiveFilterButton`, `FilterButton`, `GameCard`, `TeamSection`, `CenterSection`, `LiveGameCard`) are untouched.

- [ ] **Step 4: Commit**

```bash
git add Brackets/GamesListView.swift
git commit -m "Refetch games list when a live game ends and stop polling when none remain"
```

---

### Task 4: Manual Xcode verification

**Files:** No code changes. Manual verification only.

This project has no test target — verification is on a real simulator/device against staging data where a live game can be ended server-side during the test.

- [ ] **Step 1: Open the project in Xcode**

```bash
open /Users/humberto/Developer/ios/Brackets/Brackets.xcodeproj
```

- [ ] **Step 2: Build (⌘B)**

Expected: build succeeds. If there are compile errors:
- "Cannot find 'isFinished'" → Task 1 was missed.
- "Cannot find 'endedGame'" / "Cannot find 'makeEndedGame'" / "Cannot find 'tournamentName'" → Task 2 step was missed.
- "Extra argument 'tournamentName'" at the `LiveGameDetailView(...)` call site → Task 2 Step 1 was missed, or Task 3 Step 2 ran before Task 2.
- Any other error → re-read the modified file and compare against the corresponding task steps.

- [ ] **Step 3: Run on simulator and verify each acceptance scenario**

Pick a tournament with at least one live game. End the game server-side during the test. Verify:

1. **Games tab, single live game ends:**
   - Start on the Games tab with one live game visible as a `LiveGameCard`.
   - On the server, finish the game (post final scores + `result` for both teams).
   - Within ≤5s, the card visually transitions from the red-bordered `LiveGameCard` to the regular `GameCard` showing final scores and "Final" label.
   - The "En Vivo" filter chip disappears from the top of the filter row.
   - In Xcode console, polling stops printing live-refresh activity (timer stopped).

2. **Games tab, one of multiple live games ends:**
   - Same as above but with at least two live games.
   - Only the ended game's card switches to `GameCard`. The other live game remains as `LiveGameCard`.
   - The "En Vivo" filter chip remains visible.
   - The refresh timer continues ticking.

3. **Live game detail, game ends while viewing:**
   - Tap a live game from the Games tab → `LiveGameDetailView` opens, showing the red "En Vivo" header and live stats.
   - On the server, finish the game.
   - Within ≤5s, the screen swaps content: the live stats area is replaced with `GameResultView`'s body (final scores, full result UI, no "En Vivo" indicator).
   - The back button on the result screen returns to the Games tab (not to a stale live view).

4. **Live game detail, game already finished on first load (race condition):**
   - On the server, finish a game.
   - Before the games list auto-refetches, tap that game's card (it's still rendered as live in the cached list).
   - `LiveGameDetailView` loads, polls once, immediately swaps to `GameResultView` because the first fetched detail already shows `isFinished == true`.

5. **No regressions on non-live games:**
   - Tap a finished game → still goes to `GameResultView` directly via the existing `NavigationLink`.
   - Tap an upcoming game → still goes to `UpcomingGameView` directly.
   - These paths don't touch the new code.

6. **Polling cost unchanged when no games are live:**
   - Open the Games tab of a tournament with no live games.
   - `startLiveRefreshIfNeeded()` short-circuits (`guard hasLiveGames else { return }` on line 185), no timer starts.
   - No live-refresh activity in the console.

If any scenario fails, return to the relevant step in Task 1, 2, or 3.

- [ ] **Step 4: No commit needed (verification only).** Commit only if tweaks were made during verification.

---

## Self-review

**Spec coverage:**

- `GameDetail.isFinished` helper added → Task 1. ✓
- Games tab refetches `/games.json` when any polled live game ends → Task 3 Step 1 (`anyEnded` flag + `await loadGames()`). ✓
- Live-refresh timer stops when no live games remain → Task 3 Step 1 (`if !hasLiveGames { await MainActor.run { stopLiveRefresh() } }`). ✓
- `LiveGameDetailView` detects game-end via polling and stops timer → Task 2 Step 4 (`if detail.game.isFinished { stopRefreshTimer(); endedGame = ... }`). ✓
- `LiveGameDetailView` swaps body to `GameResultView` once `endedGame` is set → Task 2 Step 5. ✓
- Synthetic `Game` reconstruction from `(originalGame, latestDetail)` → Task 2 Step 3 (`makeEndedGame(from:)`). ✓
- `LiveGameDetailView` gains `tournamentName: String? = nil` parameter and forwards it to `GameResultView` → Task 2 Steps 1 and 5. ✓
- Call site in `GamesListView` updated to pass `tournament.name` → Task 3 Step 2. ✓
- Standings / Stats / Bracket tabs unchanged → No tasks touch those files (only `GameDetail.swift`, `LiveGameDetailView.swift`, `GamesListView.swift`). ✓
- All eight acceptance scenarios from the spec mapped to Task 4 Step 3 (scenarios 1–6 in this plan, with scenarios 1 and 2 covering the spec's "single ends" and "one of several ends" cases, scenarios 3 and 4 covering "ends while viewing" and "already finished on first load", scenario 5 covering "no regressions on non-live games", scenario 6 covering "polling cost unchanged when no games are live"). ✓

**Placeholder scan:** No "TBD" / "TODO" / "appropriate" / "as needed" / "etc." in the plan body. Every code edit shows the exact code to insert and the exact surrounding code being changed. The acceptance scenarios in Task 4 are descriptive but concrete.

**Type consistency:**
- `GameDetail.isFinished: Bool` (Task 1) is referenced as `detail.game.isFinished` in Task 2 Step 4 and Task 3 Step 1 — consistent.
- `LiveGameDetailView.tournamentName: String? = nil` (Task 2 Step 1) is referenced in Task 2 Step 5 (`tournamentName: tournamentName`) and Task 3 Step 2 (call-site `tournamentName: tournament.name`) — consistent.
- `LiveGameDetailView.endedGame: Game?` (Task 2 Step 2) is referenced in Task 2 Step 4 (assignment) and Task 2 Step 5 (`if let endedGame`) — consistent.
- `makeEndedGame(from:) -> Game` (Task 2 Step 3) signature matches the call in Task 2 Step 4 (`makeEndedGame(from: detail.game)`).
- `Game` memberwise init signature in `makeEndedGame` matches the property order in `Brackets/Game.swift:11-18` (`id`, `gameTime`, `stage`, `bracketId`, `venue`, `isLive`, `period`, `teamStats`).
- `TeamStat` initializer in `makeEndedGame` uses `(id, score, result, teamName, teamLogo)` — matches the struct definition at `Brackets/Game.swift:118-132`.
- `stopLiveRefresh()` (Task 3 Step 1) is the existing method at `GamesListView.swift:200-203`. `stopRefreshTimer()` (Task 2 Step 4) is the existing method at `LiveGameDetailView.swift:131-134`. Different names, both correct.
- `hasLiveGames` (Task 3 Step 1) is the existing computed property at `GamesListView.swift:35-37`.
- `loadGames()` (Task 3 Step 1) is the existing async method at `GamesListView.swift:222-233`.
