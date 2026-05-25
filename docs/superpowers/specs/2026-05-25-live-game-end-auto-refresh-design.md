# Auto-refresh when live games end — design

**Date:** 2026-05-25
**Status:** Approved for implementation
**Scope:** iOS app (`Brackets`) — `GameDetail.swift`, `GamesListView.swift`, `LiveGameDetailView.swift`

## Problem

The app polls `fetchGameDetail` every 5 seconds for each live game in two places, but it never reacts to a live game finishing:

- **`GamesListView`** (tournament detail → Games tab) keeps showing the ended game with the `LiveGameCard` because `game.isLive` is read from a cached `gamesResponse` that is fetched once and never refreshed.
- **`LiveGameDetailView`** keeps polling and rendering the live UI (red "En Vivo" header, "EN VIVO" indicator, live stats card) even after the game has officially finished.

The user expects: when a live game ends, the games list visually updates (live card → finished result card, "En Vivo" filter disappears when no more live games remain), and the live game detail screen swaps in-place to the `GameResultView` content for that game.

## Detection signal

A live game has "ended" when the polled `GameDetailResponse.game.teamStats` contains at least one entry with `result != nil` (the server sets `result` to "Won" / "Lost" when the game is officially finished). This matches the existing `Game.status` derivation in `Brackets/Game.swift:43-54`, so client-side semantics stay consistent across the app.

Centralize the check on `GameDetail`:

```swift
extension GameDetail {
    var isFinished: Bool {
        teamStats?.contains { $0.result != nil } ?? false
    }
}
```

Both views call `.isFinished` on the freshly fetched `GameDetail`.

## User-facing behavior

### Games tab (`GamesListView`)

While the user is viewing the Games tab and at least one game is live:

- Every 5 seconds, the existing `refreshLiveGames()` polls each live game's `fetchGameDetail`.
- If any of the polled details now reports `.isFinished == true`, after the polling batch finishes the view re-fetches `/games.json` (`loadGames()`).
- The new `gamesResponse` drives all rendering: the ended game's card changes from `LiveGameCard` to the regular `GameCard` (finished variant — date + score + "Final"), scores update, `hasLiveGames` recomputes. If no live games remain, the "En Vivo" filter chip disappears from `availableFilters`.
- If after the refresh `hasLiveGames == false`, the live refresh timer stops.
- No toast / animation / banner. The UI just renders the new data on the next pass.

### Live game detail (`LiveGameDetailView`)

While the user is viewing a live game's detail screen:

- Every 5 seconds, `loadGameDetail()` polls `fetchGameDetail`.
- If the response reports `.isFinished == true`, the view:
  1. Stops the refresh timer.
  2. Builds an updated `Game` value from `(originalGame, latestDetail)` (see "Synthetic Game" below).
  3. Sets `@State endedGame = updatedGame`.
- Once `endedGame` is non-nil, the body renders `GameResultView(game: endedGame, tournamentId: tournamentId, tournamentName: tournamentName)` instead of the live UI. `GameResultView` brings its own header, back button, and data-fetch (`.task {}`). The navigation stack entry is the same — the user's back button still returns them to `GamesListView` because `GameResultView` uses `@Environment(\.dismiss)`.
- No animated transition between live UI and result UI — a clean swap on the next render.
- One-way for the session: if the API momentarily flips the game back to live (theoretical edge case), the user stays on the result view.

### Synthetic Game reconstruction

`GameResultView` requires a `Game`, but `LiveGameDetailView` only has a `GameDetail`. Reconstruct a `Game` by combining the originally-passed `game` (for fields the detail doesn't carry) with the latest `GameDetail`:

```swift
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
```

`bracketId` is not in `GameDetail` and is carried over from the original. `isLive` is forced to `false`. `period` is irrelevant for finished games and is dropped. `teamStats` is mapped from `[GameDetailTeamStat]` to `[TeamStat]` — both already have the four fields needed (`id`, `score`, `result`, `teamName`, `teamLogo`). `GameResultView` will re-fetch its own `GameDetailResponse` via its `.task {}` immediately after appearing, so it sees the latest authoritative data anyway — the synthetic `Game` only has to be good enough to satisfy `GameResultView`'s prop type and feed the initial render.

### API change to `LiveGameDetailView`

Add an optional `tournamentName: String? = nil` initializer parameter so the view can forward it into `GameResultView` (whose `tournamentName` is also optional). Update the single call site in `GamesListView.swift:129`:

```swift
LiveGameDetailView(game: game, tournamentId: tournament.id, tournamentName: tournament.name)
```

## Implementation

### `Brackets/GameDetail.swift`

Add the `isFinished` extension somewhere after the `GameDetail` struct definition (anywhere in the file is fine; placing it adjacent to `GameDetail` keeps it discoverable).

### `Brackets/GamesListView.swift`

`refreshLiveGames()` becomes:

```swift
private func refreshLiveGames() async {
    guard let liveGames = gamesResponse?.allGames.filter({ $0.isLive }) else { return }

    var anyEnded = false
    for game in liveGames {
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
- `loadGames()` is already `@MainActor`-compatible (it mutates `@State` directly inside an `async` function; Swift handles the actor jump because `GamesListView` is a `View`).
- `stopLiveRefresh()` is called inside `MainActor.run` because it touches `liveRefreshTimer`.

No other changes to `GamesListView.swift`.

### `Brackets/LiveGameDetailView.swift`

1. Add the initializer parameter:

```swift
struct LiveGameDetailView: View {
    let game: Game
    let tournamentId: Int
    var tournamentName: String? = nil   // new
    // ...
}
```

2. Add the new state and helper:

```swift
@State private var endedGame: Game?
```

```swift
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
```

3. Update `loadGameDetail()` — after the existing successful-fetch path, check `isFinished`:

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

4. Wrap the existing body in a conditional:

```swift
var body: some View {
    if let endedGame {
        GameResultView(
            game: endedGame,
            tournamentId: tournamentId,
            tournamentName: tournamentName
        )
    } else {
        // existing ZStack { ... } body, unchanged from today,
        // including .navigationBarHidden(true), .task { ... }, .onDisappear { ... }
    }
}
```

No other changes to `LiveGameDetailView.swift`.

### `Brackets/GamesListView.swift` — call site

Update line 129 to pass `tournamentName`:

```swift
LiveGameDetailView(game: game, tournamentId: tournament.id, tournamentName: tournament.name)
```

## Acceptance

- **Games tab, single live game ends:** user is on Games tab; one game live; game ends server-side; within ≤5s the card visually transitions from `LiveGameCard` to a `GameCard` showing final scores and the "Final" label. The "En Vivo" filter chip disappears. The refresh timer stops.
- **Games tab, one of several live games ends:** Multiple games live; one ends; that card switches to `GameCard`; the others remain as `LiveGameCard`; the "En Vivo" filter chip remains; the refresh timer keeps running.
- **Live game detail, game ends while viewing:** within ≤5s of the game finishing, `LiveGameDetailView` swaps its body to `GameResultView` for the same game, showing final scores and the result UI. Back button returns to the games list, not to the live UI.
- **Live game detail, game already finished on first load:** if the user navigates into `LiveGameDetailView` for a game that the server already reports as finished (race condition), the first `loadGameDetail()` call should detect `isFinished` and immediately swap to `GameResultView`.
- **No regressions on non-live games:** existing tap behavior for finished and upcoming games on the games list still navigates to `GameResultView` / `UpcomingGameView`. Live cards still navigate to `LiveGameDetailView`.
- **Polling cost unchanged when no games are live:** before the feature, after this feature — same idle behavior (timer not started when there are no live games).

## Out of scope

- Standings / Stats / Bracket tabs do not auto-refresh when a game ends. They retain their cached data until the user navigates away and back.
- No toast / animation / banner announcing "game ended."
- No reverse transition (if the API ever flips a finished game back to live mid-session, the result view stays).
- Refresh interval remains 5 seconds. No backoff, no jitter.
- No changes to the API. Detection is purely client-side from the existing `result` field on `teamStats`.
