# Tournament list "Juegos en vivo" indicator — design

**Date:** 2026-05-25
**Status:** Approved for implementation
**Scope:** iOS app (`Brackets`) — `Tournament.swift`, `AppTheme.swift`, `ContentView.swift`

## Problem

The tournament list (embedded list card variant used from `LeagueSelectionView`) shows a tournament's name, date range, and a "Ver categoría" button. There's no signal that a tournament has games in progress *right now*, so users have to drill in to find out. A small red "Juegos en vivo" indicator on the card surfaces that signal at the list level.

## API contract

`Tournament` gains one optional field on `/tournaments.json`:

```json
{
  "id": 12,
  "name": "Juvenil Varonil",
  "live_games": true,
  ...
}
```

- `live_games: Bool?` — `true` when the tournament currently has any game with `is_live == true`. The server is responsible for the computation; the client just consumes the boolean.
- `null` or absent ⇒ treated as `false`. The app must not crash or refuse to decode a tournament that lacks the field. This matches the project's API-flexibility convention in `CLAUDE.md`.

## User-facing behavior

### When `liveGames == true`

The list card shows a small indicator directly above the "Ver categoría" button:

```
[📅 Jun 2026 - Jul 2026]              ● JUEGOS EN VIVO
                                      [ Ver categoría › ]
```

- Indicator content: a 6pt red filled circle + `"JUEGOS EN VIVO"` text (uppercase, size 10, semibold, red).
- Indicator background: none. Outlined text + dot style — no capsule fill.
- The dot pulses: opacity animates between `0.4` and `1.0` on a ~1s ease-in-out loop, started on appear. The text does not animate.
- Indicator is right-aligned, in a `VStack(alignment: .trailing, spacing: 6)` with the existing button.

### When `liveGames == false`

The card renders exactly as today. No layout shift, no reserved space.

### Scope of the indicator

- Only appears on `tournamentListCard` (used in `ContentView.allTournamentsContent`, i.e. the embedded list view from `LeagueSelectionView`).
- The full-image `TournamentCardView` (used in `ContentView.tournamentsContent`, non-embedded) is **not** modified in this iteration.

## Implementation

### `Brackets/Tournament.swift`

Add the field as an Optional and expose a non-Optional computed accessor:

```swift
struct Tournament: Identifiable, Codable, Sendable, Hashable {
    let id: Int
    let name: String
    let gender: Gender?
    let teamCount: Int?
    let image: String?
    var startDate: String? = nil
    var endDate: String? = nil
    var stage: String? = nil
    var bracketType: String? = nil
    var average: Bool? = nil
    var liveGames: Bool? = nil   // new — raw decoded value

    var hasLiveGames: Bool {     // new — call sites use this
        liveGames ?? false
    }
    // ... existing computed properties unchanged ...
}
```

**Why Optional + computed, not `Bool = false`:** Swift's synthesized `Codable` does *not* fall back to a property's default value when the JSON key is missing — only `Optional` (or properties with custom decoding) tolerate missing keys. Modeling `liveGames` as `Bool? = nil` keeps decoding tolerant of older `/tournaments.json` responses that don't yet include the field. The `hasLiveGames` computed property gives the spec's "absent ⇒ false" semantic at every call site.

`APIService.fetchTournaments` already sets `decoder.keyDecodingStrategy = .convertFromSnakeCase` (verified at `APIService.swift:247–248`), so `live_games` in JSON maps to `liveGames` in Swift automatically — no `CodingKeys` change required, no custom `init(from:)` required.

No other code in `Tournament.swift` changes.

### `Brackets/AppTheme.swift`

Add a live-indicator color to the existing `AppTheme.Colors` namespace:

```swift
static let live = Color(red: 0.92, green: 0.20, blue: 0.25)
```

Place it next to the other semantic colors (e.g., `accent`, `accentText`). No other AppTheme changes.

### `Brackets/ContentView.swift`

**New private view** at file scope, below `tournamentListCard`:

```swift
private struct LiveGamesIndicator: View {
    @State private var pulse: Bool = false

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(AppTheme.Colors.live)
                .frame(width: 6, height: 6)
                .opacity(pulse ? 1.0 : 0.4)
                .animation(
                    .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                    value: pulse
                )

            Text("JUEGOS EN VIVO")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.live)
        }
        .onAppear { pulse = true }
    }
}
```

**Modify `tournamentListCard`** — wrap the existing "Ver categoría" button in a trailing-aligned `VStack` and prepend the indicator when `liveGames` is true. The diff is localized to the `HStack` containing `Spacer()` and the button:

```swift
HStack {
    if let dateRange = tournament.formattedDateRange {
        // ... unchanged ...
    }

    Spacer()

    VStack(alignment: .trailing, spacing: 6) {
        if tournament.hasLiveGames {
            LiveGamesIndicator()
        }

        HStack(spacing: 5) {
            Text("Ver categoría")
                .font(.system(size: 13, weight: .semibold))
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .bold))
        }
        .foregroundStyle(AppTheme.Colors.accentText)
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(Capsule().fill(AppTheme.Colors.accent))
    }
}
```

No other code in `ContentView.swift` changes.

## Acceptance

- A `/tournaments.json` response that includes `"live_games": true` on a tournament shows the indicator on that tournament's list card.
- A response that omits `live_games` entirely decodes successfully; no indicator shown.
- A response with `"live_games": false` decodes successfully; no indicator shown.
- The indicator dot is visibly pulsing while the card is on screen.
- The text "JUEGOS EN VIVO" is red, uppercase, semibold, size 10.
- When the indicator is hidden, the card layout matches the current production layout pixel-for-pixel.
- The full-image `TournamentCardView` is unchanged.
- No regressions in card tap behavior — tapping anywhere on the card still navigates to `TournamentContainerView`.

## Out of scope

- No changes to `TournamentCardView` (full-image card) or any other view.
- No polling / auto-refresh of the tournaments list. Whatever live state is shown reflects the most recent `loadTournaments` call.
- No server changes are spec'd here — the API contract above is the requirement for the backend; this document is the iOS-side spec.
- No equivalent indicator inside the tournament detail (`TournamentContainerView`) tabs; the Games tab already surfaces live state.
