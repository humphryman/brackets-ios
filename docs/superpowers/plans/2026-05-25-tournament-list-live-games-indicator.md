# Tournament List "Juegos en vivo" Indicator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show a small red pulsing "JUEGOS EN VIVO" indicator above the "Ver categoría" button on the tournament list card whenever the tournament's API payload has `live_games: true`.

**Architecture:** Three files change. `Tournament.swift` gains an optional `liveGames: Bool?` decoded from `live_games` (snake_case handled by the existing `convertFromSnakeCase` decoder strategy) plus a `hasLiveGames: Bool` computed accessor that treats missing/null as `false`. `AppTheme.swift` gains a `Colors.live` red color. `ContentView.swift` adds a private `LiveGamesIndicator` view (red pulsing dot + red uppercase text) and wraps the existing "Ver categoría" button in a trailing-aligned `VStack` that shows the indicator above the button when `tournament.hasLiveGames` is true.

**Tech Stack:** Swift, SwiftUI (iOS 17+). No third-party deps. No test target.

**Project constraint:** No terminal build tools and no test target — verification is reading each modified file back and running the app in Xcode. There are no `swift test` steps. Ignore SourceKit "Cannot find type X in scope" diagnostics on sibling-file symbols — known indexing noise in this project.

**Spec:** `docs/superpowers/specs/2026-05-25-tournament-list-live-games-indicator-design.md`

---

### Task 1: Add `liveGames` field and `hasLiveGames` accessor to `Tournament`

**Files:**
- Modify: `Brackets/Tournament.swift` (two edit zones — new stored property, new computed property)

The `Tournament` struct uses the synthesized `Codable` conformance, and `APIService.fetchTournaments` already sets `decoder.keyDecodingStrategy = .convertFromSnakeCase` (`APIService.swift:247-248`). That means a new `liveGames` property maps to the JSON key `live_games` automatically — no `CodingKeys` enum required, no custom `init(from:)` required. The property must be `Optional` (not `Bool` with a default value) because Swift's synthesized `Codable` requires non-Optional keys to be present in the JSON; the spec demands tolerance of missing keys.

- [ ] **Step 1: Add the stored property**

In `Brackets/Tournament.swift`, find the existing line (currently line 20):

```swift
    var average: Bool? = nil
```

Add immediately below it:

```swift
    var liveGames: Bool? = nil
```

So lines 20–21 become:

```swift
    var average: Bool? = nil
    var liveGames: Bool? = nil
```

- [ ] **Step 2: Add the `hasLiveGames` computed accessor**

Find the existing `usesAverage` computed property (currently lines 22–24):

```swift
    var usesAverage: Bool {
        average ?? false
    }
```

Add immediately below it (before `isPlayoffs`):

```swift
    var hasLiveGames: Bool {
        liveGames ?? false
    }
```

So lines 22–28 become:

```swift
    var usesAverage: Bool {
        average ?? false
    }

    var hasLiveGames: Bool {
        liveGames ?? false
    }

    var isPlayoffs: Bool {
```

- [ ] **Step 3: Read back the file to verify**

Read `Brackets/Tournament.swift` in full. Confirm:

- The stored property `var liveGames: Bool? = nil` exists immediately after `var average: Bool? = nil`.
- The computed `hasLiveGames: Bool { liveGames ?? false }` exists immediately after `usesAverage`.
- No other property was added or removed.
- No `CodingKeys` enum was introduced (the struct still relies on synthesized `Codable`).
- No `init(from:)` was added.
- The `Gender` enum at the bottom is unchanged.

- [ ] **Step 4: Commit**

```bash
git add Brackets/Tournament.swift
git commit -m "Decode live_games on Tournament and add hasLiveGames accessor"
```

---

### Task 2: Add `live` color to `AppTheme.Colors`

**Files:**
- Modify: `Brackets/AppTheme.swift` (one edit zone — `AppTheme.Colors`)

- [ ] **Step 1: Add the color constant**

In `Brackets/AppTheme.swift`, find the existing `Status colors` block inside `struct Colors` (currently lines 40–43):

```swift
        /// Status colors
        static let positive = accent // Use accent for positive values
        static let negative = Color.red
        static let neutral = Color.white
```

Add a new line immediately below `static let neutral = Color.white`:

```swift
        static let live = Color(red: 0.92, green: 0.20, blue: 0.25)
```

So lines 40–44 become:

```swift
        /// Status colors
        static let positive = accent // Use accent for positive values
        static let negative = Color.red
        static let neutral = Color.white
        static let live = Color(red: 0.92, green: 0.20, blue: 0.25)
```

- [ ] **Step 2: Read back the file to verify**

Read `Brackets/AppTheme.swift` lines 25–48. Confirm:

- `static let live = Color(red: 0.92, green: 0.20, blue: 0.25)` is present in `struct Colors`, immediately after `static let neutral = Color.white`.
- No other lines were changed (typography, spacing, corner radius, layout, animation, and the shared UI components below — `PositionCircle`, `RecordBadge`, `ScoreText`, `LoadingView`, `ErrorView`, `EmptyStateView`, and the `View` extensions — are all untouched).

- [ ] **Step 3: Commit**

```bash
git add Brackets/AppTheme.swift
git commit -m "Add AppTheme.Colors.live for live-state UI"
```

---

### Task 3: Add `LiveGamesIndicator` view and render it above "Ver categoría" in `tournamentListCard`

**Files:**
- Modify: `Brackets/ContentView.swift` (two edit zones — restructure the bottom `HStack` inside `tournamentListCard`, and add a new private `LiveGamesIndicator` struct at file scope)

- [ ] **Step 1: Replace the bottom `HStack` of `tournamentListCard` to wrap the button in a trailing `VStack`**

Find the existing bottom `HStack` inside `tournamentListCard` (currently lines 170–193):

```swift
                HStack {
                    if let dateRange = tournament.formattedDateRange {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                                .font(.system(size: 12))
                            Text(dateRange)
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundStyle(Color(white: 0.55))
                    }

                    Spacer()

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
```

Replace with:

```swift
                HStack(alignment: .bottom) {
                    if let dateRange = tournament.formattedDateRange {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                                .font(.system(size: 12))
                            Text(dateRange)
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundStyle(Color(white: 0.55))
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

Notes on the diff:
- The outer `HStack` gains `alignment: .bottom` so that when the indicator pushes the right-side `VStack` taller, the date row on the left stays vertically aligned with the bottom of the button (the existing visual baseline).
- The "Ver categoría" capsule button is unchanged internally — it's just been moved inside the new `VStack`.
- The indicator only appears when `tournament.hasLiveGames == true`, so when there are no live games the layout is identical to today (the `VStack` collapses to just the button, same height, same position).

- [ ] **Step 2: Add the `LiveGamesIndicator` view at file scope**

In `Brackets/ContentView.swift`, find the end of `struct GenderSelectorView` (currently around lines 266–299) and the `#Preview` block that follows it (currently lines 301–303):

```swift
}

#Preview {
    ContentView(isBrowsingTournament: .constant(false))
}
```

Insert the new struct between the closing `}` of `GenderSelectorView` and the `#Preview` block, so the file ends with:

```swift
}

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

#Preview {
    ContentView(isBrowsingTournament: .constant(false))
}
```

- [ ] **Step 3: Read back the file to verify**

Read `Brackets/ContentView.swift` in full. Confirm:

- The bottom `HStack` inside `tournamentListCard` now uses `HStack(alignment: .bottom)`.
- The "Ver categoría" capsule button is now inside a `VStack(alignment: .trailing, spacing: 6)`.
- The `VStack` shows `LiveGamesIndicator()` above the button conditionally on `tournament.hasLiveGames`.
- A new `private struct LiveGamesIndicator: View` exists at file scope between `GenderSelectorView` and `#Preview`.
- `LiveGamesIndicator` has `@State private var pulse: Bool = false`, animates `Circle().opacity(...)` between `1.0` and `0.4` with `easeInOut(duration: 1.0).repeatForever(autoreverses: true)`, sets `pulse = true` in `.onAppear`, and renders `Text("JUEGOS EN VIVO")` in `font(.system(size: 10, weight: .semibold))` with `foregroundStyle(AppTheme.Colors.live)`.
- `TournamentCardView` (in `Brackets/TournamentCardView.swift`) was NOT modified — only `ContentView.swift` changed.
- Unrelated parts of `ContentView.swift` (the outer `body`, `allTournamentsContent`, `tournamentImageFallback`, `tournamentsContent`, `GenderSelectorView`) are unchanged.

- [ ] **Step 4: Commit**

```bash
git add Brackets/ContentView.swift
git commit -m "Show Juegos en vivo indicator on tournament list card"
```

---

### Task 4: Manual Xcode verification

**Files:** No code changes. Manual verification only.

This project has no test target — verification is on a real simulator/device against staging data.

- [ ] **Step 1: Open the project in Xcode**

```bash
open /Users/humberto/Developer/ios/Brackets/Brackets.xcodeproj
```

- [ ] **Step 2: Build (⌘B)**

Expected: build succeeds. If there are compile errors:
- "Cannot find 'hasLiveGames' in scope" → Task 1 Step 2 was missed.
- "Cannot find 'AppTheme.Colors.live'" → Task 2 Step 1 was missed.
- "Cannot find 'LiveGamesIndicator'" → Task 3 Step 2 was missed.
- Any other error → re-read the modified file and compare against the corresponding task steps.

- [ ] **Step 3: Run on simulator and verify each acceptance scenario from the spec**

Pick a customer/league whose tournaments use the new field. Confirm:

1. **Tournament with `"live_games": true` in the API response** — its list card shows a red pulsing dot + "JUEGOS EN VIVO" text directly above the green "Ver categoría" button. The dot visibly fades in/out on a ~1s loop. The text does not animate.
2. **Tournament with `"live_games": false` in the API response** — no indicator. Card layout is identical to production.
3. **Tournament where the API response omits `live_games` entirely** — no indicator. No decode crash, no missing-key error in the console. The tournament appears in the list normally.
4. **Multiple tournaments in the list, some live, some not** — only the live ones show the indicator. Non-live cards' layout is unchanged.
5. **Layout under live state** — the date range on the left remains aligned with the bottom of the "Ver categoría" button (the new `HStack(alignment: .bottom)` keeps that baseline as the indicator extends the right column upward).
6. **Tap behavior** — tapping anywhere on the card (including over the indicator area) still navigates to `TournamentContainerView` exactly as before.
7. **Full-image `TournamentCardView`** — open the non-embedded entry to `ContentView` (the one that uses `TournamentCardView`) and confirm it is unchanged, i.e. no indicator was accidentally added there.

If any scenario fails, return to the relevant step in Task 1, 2, or 3.

- [ ] **Step 4: No commit needed** (verification only — commit only if tweaks were made during verification).

---

## Self-review

**Spec coverage:**

- `live_games: Bool?` decoded on `Tournament`, missing/null ⇒ false → Task 1 Steps 1–2 (`liveGames` stored property + `hasLiveGames` computed accessor). ✓
- New `AppTheme.Colors.live` red color → Task 2 Step 1. ✓
- New `LiveGamesIndicator` view (6pt red filled circle with pulsing opacity, "JUEGOS EN VIVO" uppercase size 10 semibold red text, no background) → Task 3 Step 2. ✓
- Pulsing dot only (text static) → Task 3 Step 2 (animation modifier is on the `Circle`, not the `Text`). ✓
- Indicator placed in a trailing `VStack` directly above the existing "Ver categoría" button, only shown when `hasLiveGames == true` → Task 3 Step 1. ✓
- `TournamentCardView` not modified → enforced by Task 3 Step 3 verification and confirmed in Task 4 Step 3 scenario 7. ✓
- Card layout unchanged when no live games → enforced by Task 3 Step 1 (the `VStack` is the only addition; absent indicator means VStack contains only the button, which is the original layout) and verified in Task 4 Step 3 scenarios 2 and 4. ✓
- Tap behavior unchanged → verified in Task 4 Step 3 scenario 6. ✓

**Placeholder scan:** No "TBD" / "TODO" / "appropriate" / "as needed" / "etc." appears in any task body. Every code edit shows the exact code to insert and the exact code being replaced.

**Type consistency:** `Tournament.liveGames: Bool?` (Task 1) ↔ `Tournament.hasLiveGames: Bool` (Task 1) ↔ `tournament.hasLiveGames` reference in Task 3 Step 1 — all consistent. `AppTheme.Colors.live` defined in Task 2 and referenced in Task 3 Step 2 — consistent. `LiveGamesIndicator` defined in Task 3 Step 2 and referenced in Task 3 Step 1 — consistent. The font size, weight, dot diameter, opacity range, and animation duration in Task 3 Step 2 match the spec exactly.
