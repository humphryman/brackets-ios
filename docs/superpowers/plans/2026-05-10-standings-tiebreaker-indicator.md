# Standings Tiebreaker Indicator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an info icon to standings rows with a tiebreaker; tapping the icon opens a `.medium` sheet explaining how the tie was broken (FIBA score, head-to-head, or mini-table). Row tap continues to navigate to `TeamDetailView`.

**Architecture:** Decode the new `tiebreaker` object on each `TeamStanding`. Render a small `info.circle` button inside `StandingCard` when present. In `standingsList`, switch from `NavigationLink { } label: { card }` to a `ZStack` with an invisible `NavigationLink` behind the card so the icon button can intercept its own taps. Sheet content is a new `TiebreakerSheet` view with three reason-specific subviews.

**Tech Stack:** SwiftUI (iOS 17+), URLSession, `@Observable`, custom `Codable` decoders. No third-party deps. No test target — verification is manual via Xcode build + run.

**Project constraint:** No terminal build tools. The Xcode project uses `PBXFileSystemSynchronizedRootGroup` (objectVersion 77), so new `.swift` files in `Brackets/` are auto-included in the target — no pbxproj edits needed. Each task ends with a code commit; **a full Xcode build and on-device/simulator verification happens once at the end (Task 8)**.

**Spec:** `docs/superpowers/specs/2026-05-10-standings-tiebreaker-indicator-design.md`

---

### Task 1: Add tiebreaker models and extend `TeamStanding`

**Files:**
- Modify: `Brackets/APIService.swift` (TeamStanding struct lines ~67–118; add new model types in the same file alongside `TeamStanding`)

- [ ] **Step 1: Insert the new model types directly above `TeamStanding`**

Open `Brackets/APIService.swift`. Find the `// Team Standing Model` comment (around line 67). Insert the following block **immediately above** that comment:

```swift
// MARK: - Tiebreaker Models

struct Tiebreaker: Codable, Sendable, Equatable, Identifiable {
    enum Reason: String, Codable, Sendable {
        case fibaScore = "fiba_score"
        case h2h
        case miniTable = "mini_table"
    }

    let groupIndex: Int?
    let bucketId: Int
    let bucketSize: Int
    let reason: Reason
    let fibaBreakdown: [FibaEntry]?
    let h2hGames: [H2HGame]?
    let miniTable: [MiniTableEntry]?

    var id: String { "\(groupIndex ?? 0)-\(bucketId)" }

    enum CodingKeys: String, CodingKey {
        case groupIndex = "group_index"
        case bucketId = "bucket_id"
        case bucketSize = "bucket_size"
        case reason
        case fibaBreakdown = "fiba_breakdown"
        case h2hGames = "h2h_games"
        case miniTable = "mini_table"
    }
}

struct FibaEntry: Codable, Sendable, Equatable, Identifiable {
    let id: Int
    let name: String
    let fibaScore: Int

    enum CodingKeys: String, CodingKey {
        case id, name
        case fibaScore = "fiba_score"
    }
}

struct H2HGame: Codable, Sendable, Equatable, Identifiable {
    let teamA: H2HSide
    let teamB: H2HSide

    var id: String { "\(teamA.id)-\(teamB.id)-\(teamA.score)-\(teamB.score)" }

    enum CodingKeys: String, CodingKey {
        case teamA = "team_a"
        case teamB = "team_b"
    }
}

struct H2HSide: Codable, Sendable, Equatable {
    let id: Int
    let name: String
    let score: Int
    let winner: Bool
}

struct MiniTableEntry: Codable, Sendable, Equatable, Identifiable {
    let id: Int
    let name: String
    let favor: Int
    let against: Int

    var diff: Int { favor - against }
}

```

- [ ] **Step 2: Update `TeamStanding` to decode the new `tiebreaker` field and relax the old one to optional**

In the same file, locate `struct TeamStanding`. Replace its property block and `CodingKeys` with the version below. The only changes vs the current file are: (a) `tieBreaker: String` → `tieBreaker: String?`, (b) add `tiebreaker: Tiebreaker?`, (c) add `case tiebreaker` in `CodingKeys`. Everything else stays identical.

Current (around lines 68–118):
```swift
struct TeamStanding: Identifiable, Codable, Sendable {
    let id: Int
    let teamName: String
    let total: Int
    let wins: Int
    let losses: Int
    let pointsFor: Int
    let pointsAgainst: Int
    let tie: Int
    let diff: Int?
    let avg: Double?
    let tieBreaker: String
    let teamLogo: String?
    // ... computed props ...
    enum CodingKeys: String, CodingKey {
        case id = "team_season_id"
        case teamName = "name"
        case total
        case wins = "won"
        case losses = "lost"
        case pointsFor = "favor"
        case pointsAgainst = "against"
        case tie
        case diff
        case avg
        case tieBreaker = "tie_breaker"
        case teamLogo = "team_logo"
    }
}
```

Replace with:
```swift
struct TeamStanding: Identifiable, Codable, Sendable {
    let id: Int
    let teamName: String
    let total: Int
    let wins: Int
    let losses: Int
    let pointsFor: Int
    let pointsAgainst: Int
    let tie: Int
    let diff: Int?
    let avg: Double?
    let tieBreaker: String?
    let tiebreaker: Tiebreaker?
    let teamLogo: String?

    // Point differential — prefer API value, fall back to computed
    var pointDifferential: Int {
        diff ?? (pointsFor - pointsAgainst)
    }

    // Record string (e.g., "5-2")
    var record: String {
        "\(wins)-\(losses)"
    }

    // Full image URL
    var fullImageURL: String? {
        guard let teamLogo = teamLogo else { return nil }

        if teamLogo.lowercased().hasPrefix("http://") || teamLogo.lowercased().hasPrefix("https://") {
            return teamLogo
        }

        let imagePath = teamLogo.hasPrefix("/") ? String(teamLogo.dropFirst()) : teamLogo
        return "\(APIConfig.baseURL)/\(imagePath)"
    }

    enum CodingKeys: String, CodingKey {
        case id = "team_season_id"
        case teamName = "name"
        case total
        case wins = "won"
        case losses = "lost"
        case pointsFor = "favor"
        case pointsAgainst = "against"
        case tie
        case diff
        case avg
        case tieBreaker = "tie_breaker"
        case tiebreaker
        case teamLogo = "team_logo"
    }
}
```

- [ ] **Step 3: Read back the file to verify the edits applied correctly**

Read `Brackets/APIService.swift` lines 60–180 and confirm:
- The `// MARK: - Tiebreaker Models` block is present.
- `TeamStanding` has `let tieBreaker: String?` (optional) and `let tiebreaker: Tiebreaker?`.
- `CodingKeys` includes both `case tieBreaker = "tie_breaker"` and `case tiebreaker`.

- [ ] **Step 4: Commit**

```bash
git add Brackets/APIService.swift
git commit -m "Add Tiebreaker models and decode tiebreaker field on TeamStanding"
```

---

### Task 2: Create `TiebreakerSheet.swift` skeleton

**Files:**
- Create: `Brackets/TiebreakerSheet.swift`

- [ ] **Step 1: Create the file with header + reason switch + empty subviews**

Write the following to `Brackets/TiebreakerSheet.swift`:

```swift
//
//  TiebreakerSheet.swift
//  Brackets
//
//  Created by Humberto on 10/05/26.
//

import SwiftUI

struct TiebreakerSheet: View {
    let tiebreaker: Tiebreaker

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                    header

                    switch tiebreaker.reason {
                    case .fibaScore:
                        FibaScoreTable(entries: tiebreaker.fibaBreakdown ?? [])
                    case .h2h:
                        H2HList(games: tiebreaker.h2hGames ?? [])
                    case .miniTable:
                        MiniTable(entries: tiebreaker.miniTable ?? [])
                    }
                }
                .padding(.horizontal, AppTheme.Layout.screenPadding)
                .padding(.top, AppTheme.Spacing.large)
                .padding(.bottom, AppTheme.Layout.large)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
            Text("Desempate")
                .font(AppTheme.Typography.bodyBold)
                .foregroundStyle(AppTheme.Colors.accent)
                .textCase(.uppercase)
                .tracking(1)

            Text(subtitle)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.secondaryText)
        }
    }

    private var subtitle: String {
        switch tiebreaker.reason {
        case .fibaScore:  return "Resuelto por puntaje FIBA"
        case .h2h:        return "Resuelto por enfrentamiento directo"
        case .miniTable:  return "Resuelto por mini-tabla"
        }
    }
}

// MARK: - FIBA Score Table

private struct FibaScoreTable: View {
    let entries: [FibaEntry]

    var body: some View {
        EmptyView() // implemented in Task 3
    }
}

// MARK: - Head-to-Head List

private struct H2HList: View {
    let games: [H2HGame]

    var body: some View {
        EmptyView() // implemented in Task 4
    }
}

// MARK: - Mini Table

private struct MiniTable: View {
    let entries: [MiniTableEntry]

    var body: some View {
        EmptyView() // implemented in Task 5
    }
}

// MARK: - Preview

#Preview("FIBA Score") {
    TiebreakerSheet(tiebreaker: Tiebreaker(
        groupIndex: 1,
        bucketId: 2,
        bucketSize: 2,
        reason: .fibaScore,
        fibaBreakdown: [
            FibaEntry(id: 8, name: "Lakers", fibaScore: 7),
            FibaEntry(id: 12, name: "Heat", fibaScore: 6)
        ],
        h2hGames: nil,
        miniTable: nil
    ))
}
```

- [ ] **Step 2: Verify `AppTheme.Colors.accent` exists; if not, find the correct accessor**

Run a quick grep to confirm the accent color path used elsewhere:

Use the Grep tool with pattern `Colors\.accent|Colors\.lime|accentColor` over `Brackets/AppTheme.swift`. If `Colors.accent` doesn't exist, scan the file for the lime green (`#C7F24A`) accessor and replace `AppTheme.Colors.accent` in the new file with the correct path (likely `AppTheme.Colors.accent`, `AppTheme.Colors.lime`, or `AppTheme.Colors.brand`). The header is the only place that uses it.

- [ ] **Step 3: Commit**

```bash
git add Brackets/TiebreakerSheet.swift
git commit -m "Add TiebreakerSheet skeleton with reason switch and header"
```

---

### Task 3: Implement `FibaScoreTable`

**Files:**
- Modify: `Brackets/TiebreakerSheet.swift` (the `FibaScoreTable` private struct)

- [ ] **Step 1: Replace the `FibaScoreTable` body with the real implementation**

Find:
```swift
private struct FibaScoreTable: View {
    let entries: [FibaEntry]

    var body: some View {
        EmptyView() // implemented in Task 3
    }
}
```

Replace with:
```swift
private struct FibaScoreTable: View {
    let entries: [FibaEntry]

    var body: some View {
        if entries.isEmpty {
            Text("Sin datos.")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.secondaryText)
        } else {
            VStack(spacing: 0) {
                // Header row
                HStack {
                    Text("Equipo")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("FIBA")
                        .frame(width: 60, alignment: .trailing)
                }
                .font(AppTheme.Typography.tinyCaption)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .textCase(.uppercase)
                .padding(.vertical, AppTheme.Spacing.small)

                Divider()
                    .background(Color.white.opacity(0.08))

                // Data rows
                ForEach(entries) { entry in
                    HStack {
                        Text(entry.name)
                            .font(AppTheme.Typography.body)
                            .foregroundStyle(AppTheme.Colors.primaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text("\(entry.fibaScore)")
                            .font(AppTheme.Typography.bodyBold)
                            .foregroundStyle(AppTheme.Colors.primaryText)
                            .frame(width: 60, alignment: .trailing)
                    }
                    .padding(.vertical, AppTheme.Spacing.medium)

                    if entry.id != entries.last?.id {
                        Divider()
                            .background(Color.white.opacity(0.08))
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 2: Verify the typography names used exist**

Use the Grep tool over `Brackets/AppTheme.swift` for `body|bodyBold|caption|tinyCaption`. If any of `Typography.body`, `Typography.bodyBold`, `Typography.caption`, or `Typography.tinyCaption` is missing, substitute with the closest equivalent in `AppTheme.Typography` (the file is the source of truth — pick the named font that already exists). `bodyBold` and `tinyCaption` are known to exist from other views in the project.

- [ ] **Step 3: Commit**

```bash
git add Brackets/TiebreakerSheet.swift
git commit -m "Implement FibaScoreTable rendering for tiebreaker sheet"
```

---

### Task 4: Implement `H2HList`

**Files:**
- Modify: `Brackets/TiebreakerSheet.swift` (the `H2HList` private struct)

- [ ] **Step 1: Replace the `H2HList` body with the real implementation**

Find:
```swift
private struct H2HList: View {
    let games: [H2HGame]

    var body: some View {
        EmptyView() // implemented in Task 4
    }
}
```

Replace with:
```swift
private struct H2HList: View {
    let games: [H2HGame]

    var body: some View {
        if games.isEmpty {
            Text("Sin datos.")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.secondaryText)
        } else {
            VStack(spacing: 0) {
                ForEach(games) { game in
                    HStack(spacing: 12) {
                        Text(game.teamA.name)
                            .font(game.teamA.winner ? AppTheme.Typography.bodyBold : AppTheme.Typography.body)
                            .foregroundStyle(game.teamA.winner ? AppTheme.Colors.accent : AppTheme.Colors.primaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity, alignment: .trailing)

                        Text("\(game.teamA.score)")
                            .font(game.teamA.winner ? AppTheme.Typography.bodyBold : AppTheme.Typography.body)
                            .foregroundStyle(game.teamA.winner ? AppTheme.Colors.accent : AppTheme.Colors.primaryText)
                            .frame(minWidth: 32, alignment: .trailing)

                        Text("-")
                            .font(AppTheme.Typography.body)
                            .foregroundStyle(AppTheme.Colors.secondaryText)

                        Text("\(game.teamB.score)")
                            .font(game.teamB.winner ? AppTheme.Typography.bodyBold : AppTheme.Typography.body)
                            .foregroundStyle(game.teamB.winner ? AppTheme.Colors.accent : AppTheme.Colors.primaryText)
                            .frame(minWidth: 32, alignment: .leading)

                        Text(game.teamB.name)
                            .font(game.teamB.winner ? AppTheme.Typography.bodyBold : AppTheme.Typography.body)
                            .foregroundStyle(game.teamB.winner ? AppTheme.Colors.accent : AppTheme.Colors.primaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, AppTheme.Spacing.medium)

                    if game.id != games.last?.id {
                        Divider()
                            .background(Color.white.opacity(0.08))
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add Brackets/TiebreakerSheet.swift
git commit -m "Implement H2HList rendering for tiebreaker sheet"
```

---

### Task 5: Implement `MiniTable`

**Files:**
- Modify: `Brackets/TiebreakerSheet.swift` (the `MiniTable` private struct)

- [ ] **Step 1: Replace the `MiniTable` body with the real implementation**

Find:
```swift
private struct MiniTable: View {
    let entries: [MiniTableEntry]

    var body: some View {
        EmptyView() // implemented in Task 5
    }
}
```

Replace with:
```swift
private struct MiniTable: View {
    let entries: [MiniTableEntry]

    var body: some View {
        if entries.isEmpty {
            Text("Sin datos.")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.secondaryText)
        } else {
            VStack(spacing: 0) {
                // Header row
                HStack {
                    Text("Equipo")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("F")
                        .frame(width: 44, alignment: .trailing)
                    Text("C")
                        .frame(width: 44, alignment: .trailing)
                    Text("Dif")
                        .frame(width: 52, alignment: .trailing)
                }
                .font(AppTheme.Typography.tinyCaption)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .textCase(.uppercase)
                .padding(.vertical, AppTheme.Spacing.small)

                Divider()
                    .background(Color.white.opacity(0.08))

                // Data rows
                ForEach(entries) { entry in
                    HStack {
                        Text(entry.name)
                            .font(AppTheme.Typography.body)
                            .foregroundStyle(AppTheme.Colors.primaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text("\(entry.favor)")
                            .font(AppTheme.Typography.bodyBold)
                            .foregroundStyle(AppTheme.Colors.primaryText)
                            .frame(width: 44, alignment: .trailing)

                        Text("\(entry.against)")
                            .font(AppTheme.Typography.bodyBold)
                            .foregroundStyle(AppTheme.Colors.primaryText)
                            .frame(width: 44, alignment: .trailing)

                        Text(diffText(entry.diff))
                            .font(AppTheme.Typography.bodyBold)
                            .foregroundStyle(diffColor(entry.diff))
                            .frame(width: 52, alignment: .trailing)
                    }
                    .padding(.vertical, AppTheme.Spacing.medium)

                    if entry.id != entries.last?.id {
                        Divider()
                            .background(Color.white.opacity(0.08))
                    }
                }
            }
        }
    }

    private func diffText(_ value: Int) -> String {
        value > 0 ? "+\(value)" : "\(value)"
    }

    private func diffColor(_ value: Int) -> Color {
        if value > 0 { return AppTheme.Colors.positive }
        if value < 0 { return AppTheme.Colors.negative }
        return AppTheme.Colors.neutral
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add Brackets/TiebreakerSheet.swift
git commit -m "Implement MiniTable rendering for tiebreaker sheet"
```

---

### Task 6: Add the info-icon button to `StandingCard`

**Files:**
- Modify: `Brackets/StandingsView.swift` (the `StandingCard` struct, lines ~89–127)

- [ ] **Step 1: Add the `onTiebreakerTap` parameter and insert the icon button**

Find the current `StandingCard` struct:

```swift
struct StandingCard: View {
    let position: Int
    let standing: TeamStanding
    let usesAverage: Bool

    var body: some View {
        HStack(spacing: 0) {
            // Position Circle
            AppTheme.PositionCircle(position: position)
                .padding(.trailing, AppTheme.Spacing.medium)

            // Team Name
            Text(standing.teamName)
                .font(AppTheme.Typography.bodyBold)
                .foregroundStyle(AppTheme.Colors.primaryText)
                .textCase(.uppercase)
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            Spacer(minLength: AppTheme.Spacing.small)

            // Stats: FAV, CON, DIFF or AVG
            HStack(spacing: 8) {
                StatColumn(value: standing.pointsFor, label: "FAV")
                StatColumn(value: standing.pointsAgainst, label: "CON")
                if usesAverage {
                    AvgColumn(value: standing.avg)
                } else {
                    DiffColumn(value: standing.pointDifferential)
                }
            }
            .padding(.trailing, AppTheme.Spacing.medium)

            // Record Badge
            AppTheme.RecordBadge(record: standing.record)
        }
        .cardStyle()
    }
}
```

Replace with:

```swift
struct StandingCard: View {
    let position: Int
    let standing: TeamStanding
    let usesAverage: Bool
    var onTiebreakerTap: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 0) {
            // Position Circle
            AppTheme.PositionCircle(position: position)
                .padding(.trailing, AppTheme.Spacing.medium)

            // Team Name
            Text(standing.teamName)
                .font(AppTheme.Typography.bodyBold)
                .foregroundStyle(AppTheme.Colors.primaryText)
                .textCase(.uppercase)
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            Spacer(minLength: AppTheme.Spacing.small)

            // Tiebreaker info icon (only when tiebreaker present)
            if standing.tiebreaker != nil, let onTap = onTiebreakerTap {
                Button(action: onTap) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.trailing, 6)
            }

            // Stats: FAV, CON, DIFF or AVG
            HStack(spacing: 8) {
                StatColumn(value: standing.pointsFor, label: "FAV")
                StatColumn(value: standing.pointsAgainst, label: "CON")
                if usesAverage {
                    AvgColumn(value: standing.avg)
                } else {
                    DiffColumn(value: standing.pointDifferential)
                }
            }
            .padding(.trailing, AppTheme.Spacing.medium)

            // Record Badge
            AppTheme.RecordBadge(record: standing.record)
        }
        .cardStyle()
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add Brackets/StandingsView.swift
git commit -m "Add tiebreaker info icon button to StandingCard"
```

---

### Task 7: Wire icon, sheet presentation, and ZStack-based row in `StandingsView`

**Files:**
- Modify: `Brackets/StandingsView.swift` (`StandingsView` struct, `body` and `standingsList` — lines ~10–73)

- [ ] **Step 1: Add the sheet state property**

In `StandingsView`, beneath the existing `@State` properties:

```swift
@State private var result: StandingsResult?
@State private var isLoading = false
@State private var errorMessage: String?
```

Add (immediately below):

```swift
@State private var presentedTiebreaker: Tiebreaker?
```

- [ ] **Step 2: Attach the sheet modifier to the root `ZStack` in `body`**

Find the existing `body` (around lines 16–58):

```swift
var body: some View {
    ZStack {
        if isLoading {
            // ...
        } else if let errorMessage = errorMessage {
            // ...
        } else if result == nil || result!.isEmpty {
            // ...
        } else {
            ScrollView {
                // ...
            }
        }
    }
    .task {
        await loadStandings()
    }
}
```

Add a `.sheet(item:)` modifier on the root `ZStack`, **immediately above** the existing `.task { }` modifier:

```swift
.sheet(item: $presentedTiebreaker) { tb in
    TiebreakerSheet(tiebreaker: tb)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
}
.task {
    await loadStandings()
}
```

- [ ] **Step 3: Update `standingsList` to use the ZStack-with-invisible-NavigationLink pattern**

Find the current `standingsList`:

```swift
@ViewBuilder
private func standingsList(_ standings: [TeamStanding]) -> some View {
    VStack(spacing: AppTheme.Layout.itemSpacing) {
        ForEach(Array(standings.enumerated()), id: \.element.id) { index, standing in
            NavigationLink {
                TeamDetailView(standing: standing, tournamentId: tournament.id, tournamentName: tournament.name, rank: index + 1)
            } label: {
                StandingCard(position: index + 1, standing: standing, usesAverage: tournament.usesAverage)
            }
            .buttonStyle(.plain)
        }
    }
    .padding(.horizontal, AppTheme.Layout.screenPadding)
}
```

Replace with:

```swift
@ViewBuilder
private func standingsList(_ standings: [TeamStanding]) -> some View {
    VStack(spacing: AppTheme.Layout.itemSpacing) {
        ForEach(Array(standings.enumerated()), id: \.element.id) { index, standing in
            ZStack {
                NavigationLink {
                    TeamDetailView(standing: standing, tournamentId: tournament.id, tournamentName: tournament.name, rank: index + 1)
                } label: {
                    EmptyView()
                }
                .opacity(0)

                StandingCard(
                    position: index + 1,
                    standing: standing,
                    usesAverage: tournament.usesAverage,
                    onTiebreakerTap: standing.tiebreaker.map { tb in { presentedTiebreaker = tb } }
                )
            }
        }
    }
    .padding(.horizontal, AppTheme.Layout.screenPadding)
}
```

Notes on the `onTiebreakerTap` line:
- `standing.tiebreaker.map { tb in { presentedTiebreaker = tb } }` yields `nil` when there's no tiebreaker and a closure that sets state when there is one.
- That `nil` cascades through `StandingCard`'s `if standing.tiebreaker != nil, let onTap = onTiebreakerTap` check so the icon stays hidden.

- [ ] **Step 4: Commit**

```bash
git add Brackets/StandingsView.swift
git commit -m "Present tiebreaker sheet from standings rows"
```

---

### Task 8: Verify end-to-end in Xcode

**Files:** No code changes. Manual verification only.

- [ ] **Step 1: Open the project in Xcode**

```bash
open /Users/humberto/Documents/Code/ios/Brackets/Brackets.xcodeproj
```

Confirm `TiebreakerSheet.swift` appears in the file navigator under the `Brackets` group (auto-included via filesystem-synchronized groups — no manual target membership needed).

- [ ] **Step 2: Build for a simulator (Cmd-B)**

Expected: build succeeds with no errors. Any Swift compiler errors must be fixed before continuing. Common things to check if there are errors:
- `AppTheme.Colors.accent` — replace with the actual accent accessor name in `AppTheme.swift` if it's different.
- `AppTheme.Typography.caption` — replace with the actual caption font name if it's different.

- [ ] **Step 3: Run on a simulator, navigate to a tournament that has tied teams in standings**

Pick a tournament on staging known to have ties. For each of the three `reason` values present in the data:
- A tied team's row shows the `info.circle` icon between the team name area and the FAV column.
- Tapping the icon opens a `.medium` sheet titled `DESEMPATE`.
- The sheet content matches the `reason` (FIBA table, head-to-head list, or mini-table).
- Tapping anywhere else on the row navigates to `TeamDetailView` (existing behavior, unchanged).
- Teams without a tiebreaker show no icon and behave exactly as before.

- [ ] **Step 4: Verify alignment**

Scroll the standings list. The right-side FAV/CON/DIF (or AVG) columns and the record badge should remain visually aligned across rows — rows with the icon must not push the right side over. If they do, return to Task 6 and adjust the icon's leading/trailing padding.

- [ ] **Step 5: Verify grouped standings**

If a grouped tournament with ties is available, verify the same behavior inside `StandingsResult.groups`. No extra code changes expected — `standingsList` is used for both flat and grouped cases.

- [ ] **Step 6: No commit needed (verification only).** If any tweaks were made in steps 2–5, commit them with a focused message.

---

## Self-review

**Spec coverage:**
- Models: Task 1 ✓
- Icon in row (between name area and stats): Task 6 ✓
- Subtle gray, ~14pt, 28×28 tap target: Task 6 ✓
- Icon only when tiebreaker != nil: Task 6 ✓
- Row tap navigates to TeamDetailView: Task 7 ✓
- Icon tap opens sheet: Tasks 6 + 7 ✓
- `.medium` sheet with drag indicator: Task 7 ✓
- Title "Desempate" + reason-mapped subtitle: Task 2 ✓
- FIBA score table: Task 3 ✓
- H2H list with winner styling: Task 4 ✓
- Mini-table with colored Dif: Task 5 ✓
- Empty fallbacks ("Sin datos."): Tasks 3, 4, 5 ✓
- Right-side alignment preserved: Task 8 step 4 ✓
- Grouped standings: Task 8 step 5 ✓

**Placeholder scan:** No TBD/TODO/"appropriate"/"as needed" left. Every code block is complete.

**Type consistency:**
- `Tiebreaker.id` returns `String` — `sheet(item:)` requires `Identifiable`, which it satisfies. ✓
- `H2HGame.id` returns `String` — `Identifiable` ✓
- `FibaEntry`, `MiniTableEntry` both `Identifiable` via `Int id`. ✓
- `onTiebreakerTap: (() -> Void)?` defined in Task 6, used in Task 7 with the same name. ✓
- `presentedTiebreaker` typed as `Tiebreaker?` defined in Task 7 step 1, used in step 2 + step 3 with the same name. ✓
