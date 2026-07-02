# Multi-Bracket View with Tabs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a bracket tab bar to the Bracket view so a tournament with multiple brackets can switch between them, each rendered with the existing bracket logic (extended to support Octavos) filtered to that bracket's games.

**Architecture:** Add `type` to `BracketInfo`; extract the games-view carousel into a generic shared `ChipCarousel`; generalize `BracketView`'s round builder to take a bracket `type` + filtered games and add an Octavos first round; then add bracket state + the tab bar. Built so each task compiles and single-bracket behavior is preserved until the final task.

**Tech Stack:** SwiftUI (iOS 17+), pure Swift, URLSession, `AppTheme` tokens. No third-party deps.

**Depends on:** the `games-view-redesign` branch (provides `Game.bracket`/`Game.bracketId`, `BracketInfo`, `GamesResponse.brackets`, and the carousel to extract). Branch this work off `games-view-redesign`.

## Global Constraints

- **No terminal build/test tooling** — verify in **Xcode**: build **⌘B** and inspect SwiftUI `#Preview`s. No XCTest step.
- **Dark mode only**; accent lime `AppTheme.Colors.accent`; UI text Spanish; `es_MX`; `AppConfig.DateTime.apiTimeZone`.
- **Bracket types:** `"octavos"` → Octavos(8)→Cuartos(4)→Semifinal(2)→Final(1)+3º; `"quarterfinals"` → Cuartos→Semifinal→Final+3º; `"semifinals"`/unknown → Semifinal→Final+3º. Stage strings for lookup: `"Octavos de final"`, `"Cuartos de Final"`, `"Semifinal"`, `"Final"`, `"Tercer Lugar"`.
- **Tabs:** show a tab per bracket in the API `brackets` list (ordered by `position`), tab bar visible only when `brackets.count >= 2`; exactly-one selected; the selected bracket renders using its games (`game.bracket == name`) and its `type`.
- **Chip style (shared carousel):** selected = clear fill + 2.5pt accent stroke + white text; unselected = `Color(white: 0.08)` fill + `Color(white: 0.83)` text; arrows = `Color(white: 0.14)` circle + `Color(white: 0.83)` chevron; both arrows shown together on overflow; HStack `[‹][scroll][›]` layout.
- Do **not** run `git commit` unless the executor is explicitly authorized; commit steps are written for completeness — otherwise leave changes uncommitted.
- SourceKit "cannot find X in scope" cross-file errors are false positives (same-module symbols); ignore them.

---

## File Structure

- **Modify `Brackets/Game.swift`:** add `BracketInfo.type`.
- **Create `Brackets/ChipCarousel.swift`:** generic `ChipCarousel<Item: Hashable>` + its two preference keys.
- **Modify `Brackets/GamesListView.swift`:** delete `GroupFilterCarousel` + the two carousel preference keys; make `GameGroupChip: Hashable`; use `ChipCarousel`; update the carousel preview.
- **Modify `Brackets/BracketView.swift`:** generalize round builder (+ Octavos), `makeUpdatedGame` fix, then bracket state + tab bar + per-bracket filtering.

---

### Task 1: Model — `BracketInfo.type`

**Files:**
- Modify: `Brackets/Game.swift`

**Interfaces:**
- Produces: `BracketInfo.type: String?` (values `"octavos"`/`"quarterfinals"`/`"semifinals"`).

- [ ] **Step 1: Add the `type` property + coding key**

In `struct BracketInfo` (in `Game.swift`), add the property after `let name: String`:

```swift
    let type: String?
```

and add `type` to its `CodingKeys`:

```swift
    enum CodingKeys: String, CodingKey {
        case name, position, type
        case typeLabel = "type_label"
    }
```

- [ ] **Step 2: Build**

Run: **⌘B**. Expected: builds. `BracketInfo` decodes `type` when present, tolerates absence (optional). No behavior change yet.

- [ ] **Step 3: Commit** (only if authorized)

```bash
git add Brackets/Game.swift
git commit -m "Add type to BracketInfo"
```

---

### Task 2: Extract shared `ChipCarousel` and rewire the games view

**Files:**
- Create: `Brackets/ChipCarousel.swift`
- Modify: `Brackets/GamesListView.swift`

**Interfaces:**
- Consumes: `AppTheme` tokens.
- Produces: `struct ChipCarousel<Item: Hashable>: View` with `items: [Item]`, `label: (Item) -> String`, `@Binding var selected: Item?`. Used by `GamesListView` (Task 2) and `BracketView` (Task 4).
- Also: `GameGroupChip` becomes `Hashable`.

- [ ] **Step 1: Create `Brackets/ChipCarousel.swift`**

```swift
//
//  ChipCarousel.swift
//  Brackets
//

import SwiftUI

private struct CarouselContentWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

private struct CarouselContainerWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

/// Horizontally scrollable chip row with overflow chevron buttons. Generic over any
/// Hashable item; `label` provides the chip text (and scroll id).
struct ChipCarousel<Item: Hashable>: View {
    let items: [Item]
    let label: (Item) -> String
    @Binding var selected: Item?

    @State private var contentWidth: CGFloat = 0
    @State private var viewportWidth: CGFloat = 0
    @State private var leadingIndex: Int = 0

    private var isOverflowing: Bool { contentWidth > viewportWidth + 1 }

    var body: some View {
        ScrollViewReader { proxy in
            HStack(spacing: 6) {
                if isOverflowing {
                    arrow("chevron.left") { step(-1, proxy) }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppTheme.Spacing.small) {
                        ForEach(items, id: \.self) { item in
                            chipButton(item).id(label(item))
                        }
                    }
                    .padding(.horizontal, 2)
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(key: CarouselContentWidthKey.self, value: geo.size.width)
                        }
                    )
                }
                .onPreferenceChange(CarouselContentWidthKey.self) { contentWidth = $0 }
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(key: CarouselContainerWidthKey.self, value: geo.size.width)
                    }
                )
                .onPreferenceChange(CarouselContainerWidthKey.self) { viewportWidth = $0 }

                if isOverflowing {
                    arrow("chevron.right") { step(1, proxy) }
                }
            }
            .padding(.horizontal, AppTheme.Layout.screenPadding)
            .onChange(of: items) { leadingIndex = 0 }
        }
        .frame(height: 44)
    }

    /// Scroll the row by roughly one viewport of chips in `direction` (+1 right, -1 left).
    private func step(_ direction: Int, _ proxy: ScrollViewProxy) {
        guard !items.isEmpty else { return }
        let avg = contentWidth > 0 ? contentWidth / CGFloat(items.count) : 90
        let page = max(1, Int((viewportWidth / avg).rounded(.down)))
        leadingIndex = min(max(0, leadingIndex + direction * page), items.count - 1)
        withAnimation(.easeInOut(duration: 0.3)) {
            proxy.scrollTo(label(items[leadingIndex]), anchor: .leading)
        }
    }

    private func chipButton(_ item: Item) -> some View {
        let isSelected = selected == item
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selected = item }
        } label: {
            Text(label(item))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isSelected ? AppTheme.Colors.primaryText : Color(white: 0.83))
                .padding(.horizontal, 18)
                .padding(.vertical, 9)
                .background(Capsule().fill(isSelected ? Color.clear : Color(white: 0.08)))
                .overlay(Capsule().stroke(AppTheme.Colors.accent, lineWidth: isSelected ? 2.5 : 0))
        }
        .buttonStyle(.plain)
    }

    private func arrow(_ system: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color(white: 0.83))
                .frame(width: 36, height: 36)
                .background(Circle().fill(Color(white: 0.14)))
                .shadow(color: .black.opacity(0.4), radius: 4)
        }
        .buttonStyle(.plain)
    }
}

#Preview("Chip carousel") {
    struct Wrap: View {
        @State var sel: String? = "Grupo 1"
        var items: [String] {
            (1...13).map { "Grupo \($0)" } + ["Playoffs", "Playoffs 2", "Playoffs 3"]
        }
        var body: some View {
            ChipCarousel(items: items, label: { $0 }, selected: $sel)
        }
    }
    return ZStack { Color.black.ignoresSafeArea(); Wrap() }
}
```

- [ ] **Step 2: Delete the old carousel + preference keys from `GamesListView.swift`**

Delete the entire `struct GroupFilterCarousel: View { … }` and the two preference-key structs `private struct CarouselContentWidthKey { … }` and `private struct CarouselContainerWidthKey { … }` from `GamesListView.swift` (they now live in `ChipCarousel.swift`). Leave `GameGroupChip` in place.

- [ ] **Step 3: Make `GameGroupChip` Hashable**

Change its declaration:

```swift
struct GameGroupChip: Identifiable, Equatable, Hashable {
```

(The stored `name: String` and `kind: Kind` are both Hashable, so conformance is synthesized. The computed `id` is unaffected.)

- [ ] **Step 4: Use `ChipCarousel` in the games list**

Replace the usage:

```swift
                    GroupFilterCarousel(chips: chips, selected: $selectedChip)
```

with:

```swift
                    ChipCarousel(items: chips, label: \.name, selected: $selectedChip)
```

- [ ] **Step 5: Update the games carousel preview**

In `GamesListView.swift`, find `#Preview("Group carousel")` and replace its `GroupFilterCarousel(chips: chips, selected: $sel)` line with:

```swift
            ChipCarousel(items: chips, label: \.name, selected: $sel)
```

- [ ] **Step 6: Build and verify in Xcode**

Run: **⌘B**, then open the **"Chip carousel"** preview (in `ChipCarousel.swift`) and the **"Group carousel"** preview (in `GamesListView.swift`); also run the app's Games tab.
Expected: builds with no references to `GroupFilterCarousel` remaining (grep to confirm: `grep -n GroupFilterCarousel Brackets/*.swift` → nothing). Both previews show the chip row with "Grupo 1" selected (accent outline), the rest gray, and `‹ ›` arrows on overflow that scroll. The Games tab group filter behaves exactly as before.

- [ ] **Step 7: Commit** (only if authorized)

```bash
git add Brackets/ChipCarousel.swift Brackets/GamesListView.swift
git commit -m "Extract shared ChipCarousel; rewire games group filter"
```

---

### Task 3: Generalize the bracket round builder + add Octavos + fix live-update

**Files:**
- Modify: `Brackets/BracketView.swift`

**Interfaces:**
- Consumes: `Game.stage`/`bracketId`/`group`/`bracket`.
- Produces: computed `activeType: String` and `bracketGames: [Game]` that the round builder and layout read; an Octavos round when `activeType == "octavos"`. Single-bracket behavior is unchanged (this task keeps `activeType = tournament.bracketType`, `bracketGames = games`).

- [ ] **Step 1: Add `activeType` and `bracketGames` computed properties**

In `BracketView`, add near the other computed properties (e.g. after `hasLiveGames`):

```swift
    private var activeType: String {
        tournament.bracketType?.lowercased() ?? ""
    }

    private var bracketGames: [Game] {
        games
    }
```

- [ ] **Step 2: Read `activeType`/`bracketGames` in the layout + lookup helpers**

In `matchupSpacing(for:)`, replace:

```swift
        let bracketType = tournament.bracketType?.lowercased() ?? ""
        let baseSpacing: CGFloat = bracketType == "semifinals" ? 80 : 24
```

with:

```swift
        let baseSpacing: CGFloat = activeType == "semifinals" ? 80 : 24
```

In `gameForSlot(stage:slot:)`, replace `let stageGames = games.filter { … }` so it filters `bracketGames`:

```swift
        let stageGames = bracketGames.filter { game in
            guard let gameStage = game.stage else { return false }
            return stageMatches(gameStage: gameStage, target: stage)
        }
```

In `bracketPager(pageWidth:)`, delete the now-unused line `let bracketType = tournament.bracketType?.lowercased() ?? ""`.

- [ ] **Step 3: Replace `buildRounds()` to read `activeType` and support Octavos**

Replace the entire `buildRounds()` method with:

```swift
    private func buildRounds() -> [BracketRound] {
        let type = activeType
        var rounds: [BracketRound] = []
        var previous: [BracketMatchup] = []

        // Octavos round (only for octavos-type brackets)
        if type == "octavos" {
            let r16 = (1...8).map { slot in
                buildMatchup(stage: "Octavos de final", slot: slot, propagation: nil)
            }
            rounds.append(BracketRound(name: "Octavos de Final", matchups: r16))
            previous = r16
        }

        // QF round (octavos or quarterfinals)
        if type == "octavos" || type == "quarterfinals" {
            let qfMatchups = (1...4).map { slot -> BracketMatchup in
                let prop: (home: Team?, away: Team?)? = previous.isEmpty
                    ? nil
                    : propagatedPair(from: previous, slotIndex: slot - 1, useLoser: false)
                return buildMatchup(stage: "Cuartos de Final", slot: slot, propagation: prop)
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

- [ ] **Step 4: Preserve `group`/`bracket` in `makeUpdatedGame`**

In `makeUpdatedGame(from:original:)`, add the two trailing arguments to the constructed `Game`:

```swift
        return Game(
            id: detail.id,
            gameTime: detail.gameTime ?? original.gameTime,
            stage: detail.stage ?? original.stage,
            bracketId: original.bracketId,
            venue: detail.venue ?? original.venue,
            isLive: !detail.isFinished,
            period: detail.period ?? original.period,
            teamStats: mappedStats ?? original.teamStats,
            group: original.group,
            bracket: original.bracket
        )
```

- [ ] **Step 5: Build and verify in Xcode**

Run: **⌘B**, then open a tournament's Bracket tab.
Expected: builds. A `quarterfinals` tournament renders **identically** to before (QF→SF→Final); a `semifinals` tournament renders SF→Final. Live-updating a bracket game keeps it in place (bracket/group preserved). No visual change for existing brackets — this task only refactors + adds the (dormant until Task 4) Octavos path.

- [ ] **Step 6: Commit** (only if authorized)

```bash
git add Brackets/BracketView.swift
git commit -m "Generalize bracket round builder; add Octavos; preserve bracket on live update"
```

---

### Task 4: Multi-bracket state and tab bar

**Files:**
- Modify: `Brackets/BracketView.swift`

**Interfaces:**
- Consumes: `ChipCarousel` (Task 2), `BracketInfo.type` (Task 1), `GamesResponse.brackets`, the generalized builder (Task 3).
- Produces: bracket tab bar + per-bracket rendering.

- [ ] **Step 1: Add bracket state**

In `BracketView`, add alongside the other `@State` properties:

```swift
    @State private var brackets: [BracketInfo] = []
    @State private var selectedBracketName: String?
    @State private var didInitBracket = false
```

- [ ] **Step 2: Make `activeType`/`bracketGames` bracket-aware**

Replace the `activeType` and `bracketGames` computed properties (added in Task 3) with:

```swift
    private var selectedBracket: BracketInfo? {
        brackets.first { $0.name == selectedBracketName }
    }

    private var activeType: String {
        (selectedBracket?.type ?? tournament.bracketType)?.lowercased() ?? ""
    }

    private var bracketGames: [Game] {
        guard !brackets.isEmpty, let name = selectedBracketName else { return games }
        return games.filter { $0.bracket == name }
    }
```

- [ ] **Step 3: Capture brackets + init selection in `loadGames`**

Replace the success body of `loadGames()`:

```swift
        do {
            let response = try await APIService.shared.fetchGamesResponse(for: tournament.id)
            games = response.allGames
            brackets = (response.brackets ?? []).sorted { ($0.position ?? Int.max) < ($1.position ?? Int.max) }
            if !didInitBracket {
                selectedBracketName = brackets.first?.name
                didInitBracket = true
            }
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
```

- [ ] **Step 4: Add the tab bar to `body`**

Wrap the existing `ZStack { … }` in `body` with a `VStack` that puts the tab bar on top. Replace the opening of `body`:

```swift
    var body: some View {
        ZStack {
```

with:

```swift
    var body: some View {
        VStack(spacing: 0) {
            if brackets.count >= 2 {
                ChipCarousel(items: brackets.map(\.name), label: { $0 }, selected: $selectedBracketName)
                    .padding(.vertical, AppTheme.Spacing.small)
                    .onChange(of: selectedBracketName) {
                        currentPage = 0
                        dragOffset = 0
                    }
            }
            ZStack {
```

and add a matching closing brace for the new `VStack` at the end of `body`. The current `body` ends with:

```swift
        }
        .task {
            await loadGames()
            startLiveRefreshIfNeeded()
        }
        .onDisappear {
            stopLiveRefresh()
        }
    }
```

Change it to (the `.task`/`.onDisappear` stay on the outer `VStack`, and the inner `ZStack` gets its own closing brace):

```swift
            }
        }
        .task {
            await loadGames()
            startLiveRefreshIfNeeded()
        }
        .onDisappear {
            stopLiveRefresh()
        }
    }
```

> Implementation note: the inner `ZStack` (loading / error / empty / `GeometryReader`) is unchanged; you are only adding a `VStack { if brackets.count >= 2 { ChipCarousel … }; ZStack { …existing… } }` wrapper. Verify brace balance after this edit.

- [ ] **Step 5: Build and verify in Xcode**

Run: **⌘B**, open the Bracket tab on a tournament that returns multiple brackets.
Expected: builds. A tab bar of bracket names ("Playoffs", "Playoffs 2", …) appears above the bracket, styled like the games chips, with `‹ ›` arrows on overflow. The first bracket is selected on load; tapping a tab renders that bracket's games and its round depth (an `octavos` bracket shows Octavos→Cuartos→Semifinal→Final), resetting the horizontal page. A single-bracket / legacy tournament shows no tab bar and renders as before.

- [ ] **Step 6: Commit** (only if authorized)

```bash
git add Brackets/BracketView.swift
git commit -m "Add bracket tabs and per-bracket rendering to BracketView"
```

---

## Self-Review

**Spec coverage:**
- `BracketInfo.type` → Task 1. ✔
- Shared `ChipCarousel` extraction + games rewire + `GameGroupChip: Hashable` → Task 2. ✔
- Bracket state, per-bracket game filtering, tab-bar visibility (`>= 2`), page reset → Task 4. ✔
- Generalized builder + Octavos (8→4→2→1) + slot lookup within `bracketGames` + `matchupSpacing` on active type → Task 3. ✔
- Legacy fallback (no brackets → all games + `tournament.bracketType`, no tab bar) → Task 4 Step 2 (`bracketGames`) + Step 4 (`>= 2` guard). ✔
- `makeUpdatedGame` preserves `group`/`bracket` → Task 3 Step 4. ✔
- Unchanged: matchup visuals, connectors, live badge, navigation → not modified. ✔

**Placeholder scan:** No TBD/TODO; every step carries complete code.

**Type consistency:** `ChipCarousel(items:label:selected:)`, `activeType`, `bracketGames`, `selectedBracket`, `selectedBracketName`, `brackets`, `buildRounds()`, `gameForSlot`, `matchupSpacing(for:)`, `BracketInfo.type` are consistent across tasks. Task 3 introduces `activeType`/`bracketGames` reading `tournament.bracketType`/`games`; Task 4 redefines those same two properties to be bracket-aware (same names/types), so the builder and layout pick up multi-bracket behavior without further edits.
