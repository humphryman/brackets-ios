# Collapsible Table Standings Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign grouped standings as one collapsible card per group containing a compact table (column header + tight rows), matching the mockup, with the first group expanded and the rest collapsed on load.

**Architecture:** All changes live in `Brackets/StandingsView.swift` (view-only; no model/API changes). New small SwiftUI components build bottom-up: shared column-width constants and cells → header + row → collapsible group card → rewired `StandingsView`. A shared `StandingsTableBody` is reused by both the grouped (collapsible) and flat (always-visible) cases to stay DRY.

**Tech Stack:** SwiftUI (iOS 17+), pure Swift, `@Observable`/`@State`, no third-party deps. Existing `AppTheme` design tokens.

## Global Constraints

- **No terminal build/test tooling** — verification is done in **Xcode**: build with **⌘B** and inspect the component's **SwiftUI `#Preview`** canvas. There is no XCTest run step. Each task adds/uses a `#Preview` as its verification harness.
- **Dark mode only**, accent lime-green `AppTheme.Colors.accent` (`#a3ff12`).
- **All UI text in Spanish.** Column headers: `#`, `EQUIPOS`, `J`, `G`, `P`, `FAV`, `CON`, `AVG`/`DIF`.
- **Data mapping (existing `TeamStanding`):** `J`=`total`, `G`=`wins`, `P`=`losses`, `FAV`=`pointsFor`, `CON`=`pointsAgainst`, last=`avg` (AVG) or `pointDifferential` (DIF).
- **Last column is conditional:** AVG when `tournament.usesAverage == true`, else DIF.
- **AVG format:** `String(format: "%.3f", value)`, unsigned; nil → `"-"`.
- Only touch `Brackets/StandingsView.swift`. Do **not** delete `AppTheme.RecordBadge` (shared design-system component).
- **Do not run `git commit` unless the executor is explicitly told to.** The user's standing preference is to wait for an explicit commit instruction. Commit steps below are written for completeness; skip them (leave changes staged/unstaged) unless the user has authorized committing.

---

## File Structure

- **Modify:** `Brackets/StandingsView.swift`
  - Add: `StandingsCol` (column-width constants), `AvgPill`, `DiffCell`, `StandingsTableHeader`, `StandingsTableRow`, `StandingsTableBody`, `GroupStandingsCard`.
  - Change: `StandingsView` — add `expandedGroups`/`didInitExpansion` state, `toggle(_:)`, rewrite `standingsScroll` grouped + flat rendering, init expansion after load.
  - Remove: `StandingCard`, `StatColumn`, `AvgColumn`, `DiffColumn` (local, unused elsewhere).

---

### Task 1: Column constants, cells, header, and row

**Files:**
- Modify: `Brackets/StandingsView.swift`

**Interfaces:**
- Consumes: `TeamStanding` (`total`, `wins`, `losses`, `pointsFor`, `pointsAgainst`, `avg`, `pointDifferential`, `teamName`, `tiebreaker`, `id`); `AppTheme`.
- Produces:
  - `enum StandingsCol` with static `CGFloat` widths: `rank`, `narrow`, `wide`, `last`, `hSpacing`, `rowVPadding`.
  - `struct AvgPill { let value: Double? }`
  - `struct DiffCell { let value: Int }`
  - `struct StandingsTableHeader { let usesAverage: Bool }`
  - `struct StandingsTableRow { let position: Int; let standing: TeamStanding; let usesAverage: Bool; var onTiebreakerTap: (() -> Void)? }`

- [ ] **Step 1: Add column constants and the AVG/DIF cells**

Add near the top of `StandingsView.swift`, after the `import SwiftUI` / `enum StandingsSubTab` block:

```swift
// MARK: - Table layout

/// Shared fixed column widths so the header row and every team row line up.
enum StandingsCol {
    static let rank: CGFloat = 18      // "#"
    static let narrow: CGFloat = 22    // J, G, P
    static let wide: CGFloat = 36      // FAV, CON
    static let last: CGFloat = 52      // AVG / DIF
    static let hSpacing: CGFloat = 6
    static let rowVPadding: CGFloat = 10
}

/// AVG value rendered as accent-green text on a subtle green-tinted pill.
struct AvgPill: View {
    let value: Double?

    private var text: String {
        guard let value else { return "-" }
        return String(format: "%.3f", value)
    }

    var body: some View {
        Text(text)
            .font(AppTheme.Typography.smallCaption)
            .foregroundStyle(AppTheme.Colors.accent)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(AppTheme.Colors.accent.opacity(0.15))
            )
    }
}

/// Signed point differential, colored positive/negative/neutral.
struct DiffCell: View {
    let value: Int

    private var color: Color {
        if value > 0 { return AppTheme.Colors.positive }
        if value < 0 { return AppTheme.Colors.negative }
        return AppTheme.Colors.neutral
    }

    var body: some View {
        Text(value > 0 ? "+\(value)" : "\(value)")
            .font(AppTheme.Typography.smallCaption)
            .foregroundStyle(color)
    }
}
```

- [ ] **Step 2: Add the table header row**

Append after `DiffCell`:

```swift
/// Column-label row: `#  EQUIPOS  J  G  P  FAV  CON  AVG/DIF`.
struct StandingsTableHeader: View {
    let usesAverage: Bool

    var body: some View {
        HStack(spacing: StandingsCol.hSpacing) {
            Text("#").frame(width: StandingsCol.rank, alignment: .leading)
            Text("EQUIPOS").frame(maxWidth: .infinity, alignment: .leading)
            Text("J").frame(width: StandingsCol.narrow)
            Text("G").frame(width: StandingsCol.narrow)
            Text("P").frame(width: StandingsCol.narrow)
            Text("FAV").frame(width: StandingsCol.wide)
            Text("CON").frame(width: StandingsCol.wide)
            Text(usesAverage ? "AVG" : "DIF").frame(width: StandingsCol.last)
        }
        .font(AppTheme.Typography.tinyCaption)
        .foregroundStyle(AppTheme.Colors.secondaryText)
        .textCase(.uppercase)
    }
}
```

- [ ] **Step 3: Add the team row**

Append after `StandingsTableHeader`:

```swift
/// One team row inside the standings table. Widths mirror `StandingsTableHeader`.
struct StandingsTableRow: View {
    let position: Int
    let standing: TeamStanding
    let usesAverage: Bool
    var onTiebreakerTap: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: StandingsCol.hSpacing) {
            Text("\(position)")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .frame(width: StandingsCol.rank, alignment: .leading)

            HStack(spacing: 4) {
                Text(standing.teamName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if standing.tiebreaker != nil, let onTap = onTiebreakerTap {
                    Button(action: onTap) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            numeric(standing.total)
            numeric(standing.wins)
            numeric(standing.losses)
            numeric(standing.pointsFor, width: StandingsCol.wide)
            numeric(standing.pointsAgainst, width: StandingsCol.wide)

            Group {
                if usesAverage {
                    AvgPill(value: standing.avg)
                } else {
                    DiffCell(value: standing.pointDifferential)
                }
            }
            .frame(width: StandingsCol.last)
        }
        .padding(.vertical, StandingsCol.rowVPadding)
    }

    private func numeric(_ value: Int, width: CGFloat = StandingsCol.narrow) -> some View {
        Text("\(value)")
            .font(AppTheme.Typography.smallCaption)
            .foregroundStyle(AppTheme.Colors.primaryText)
            .frame(width: width)
    }
}
```

- [ ] **Step 4: Add a preview to verify the row/header render**

Add a second preview at the bottom of the file (below the existing `#Preview`):

```swift
#Preview("Table row") {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 0) {
            StandingsTableHeader(usesAverage: true)
            StandingsTableRow(
                position: 1,
                standing: TeamStanding(
                    id: 1, teamName: "San Luis Potosí B", total: 5, wins: 4, losses: 1,
                    pointsFor: 434, pointsAgainst: 386, tie: 0, diff: 48, avg: 1.124,
                    tieBreaker: nil, tiebreaker: nil, teamLogo: nil
                ),
                usesAverage: true
            )
        }
        .padding()
    }
}
```

> Note: confirm the `TeamStanding` memberwise initializer argument order/labels against `Brackets/APIService.swift` when typing this preview; adjust to match if the struct differs.

- [ ] **Step 5: Build and verify in Xcode**

Run: Build with **⌘B** in Xcode (scheme `Brackets`).
Expected: Build succeeds. Open the **"Table row"** `#Preview` canvas — a header row `# EQUIPOS J G P FAV CON AVG` sits above one row showing `1  SAN LUIS POTOSÍ B … 434 386` with `1.124` in a green pill, columns aligned.

- [ ] **Step 6: Commit** (only if the user has authorized committing)

```bash
git add Brackets/StandingsView.swift
git commit -m "Add standings table cells, header, and row components"
```

---

### Task 2: Shared table body + collapsible group card

**Files:**
- Modify: `Brackets/StandingsView.swift`

**Interfaces:**
- Consumes: `StandingsTableHeader`, `StandingsCol`, `TeamStanding`, `AppTheme` from Task 1.
- Produces:
  - `struct StandingsTableBody<Row: View>` with `usesAverage: Bool`, `standings: [TeamStanding]`, `@ViewBuilder rowBuilder: (Int, TeamStanding) -> Row`.
  - `struct GroupStandingsCard<Row: View>` with `title: String`, `usesAverage: Bool`, `isExpanded: Bool`, `onToggle: () -> Void`, `standings: [TeamStanding]`, `@ViewBuilder rowBuilder: (Int, TeamStanding) -> Row`.

- [ ] **Step 1: Add the shared table body**

Append after `StandingsTableRow`:

```swift
/// Header row + team rows with hairline dividers. Reused by grouped and flat cases.
struct StandingsTableBody<Row: View>: View {
    let usesAverage: Bool
    let standings: [TeamStanding]
    @ViewBuilder let rowBuilder: (Int, TeamStanding) -> Row

    var body: some View {
        VStack(spacing: 0) {
            StandingsTableHeader(usesAverage: usesAverage)
                .padding(.bottom, 2)
            ForEach(Array(standings.enumerated()), id: \.element.id) { index, standing in
                rowBuilder(index, standing)
                if index < standings.count - 1 {
                    Divider()
                        .overlay(AppTheme.Colors.separator)
                }
            }
        }
    }
}
```

- [ ] **Step 2: Add the collapsible group card**

Append after `StandingsTableBody`:

```swift
/// One group rendered as a card: tappable title + chevron, and (when expanded) the table.
struct GroupStandingsCard<Row: View>: View {
    let title: String
    let usesAverage: Bool
    let isExpanded: Bool
    let onToggle: () -> Void
    let standings: [TeamStanding]
    @ViewBuilder let rowBuilder: (Int, TeamStanding) -> Row

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onToggle) {
                HStack {
                    Text(title)
                        .font(AppTheme.Typography.headline)
                        .foregroundStyle(AppTheme.Colors.primaryText)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                StandingsTableBody(usesAverage: usesAverage, standings: standings, rowBuilder: rowBuilder)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large)
                .fill(AppTheme.Colors.cardBackground)
        )
    }
}
```

- [ ] **Step 3: Add a preview for the collapsible card**

Add below the "Table row" preview:

```swift
#Preview("Group card") {
    ZStack {
        Color.black.ignoresSafeArea()
        let sample = (1...4).map { i in
            TeamStanding(
                id: i, teamName: "Equipo \(i)", total: 5, wins: 5 - i, losses: i - 1,
                pointsFor: 400 + i, pointsAgainst: 380 + i, tie: 0, diff: 20 - i,
                avg: 1.1 - Double(i) / 20.0, tieBreaker: nil, tiebreaker: nil, teamLogo: nil
            )
        }
        GroupStandingsCard(
            title: "Grupo 1", usesAverage: true, isExpanded: true, onToggle: {},
            standings: sample
        ) { index, standing in
            StandingsTableRow(position: index + 1, standing: standing, usesAverage: true)
        }
        .padding()
    }
}
```

- [ ] **Step 4: Build and verify in Xcode**

Run: Build with **⌘B**.
Expected: Build succeeds. The **"Group card"** preview shows a rounded card titled `Grupo 1` with a chevron, a column header, and 4 divider-separated rows. (You can flip `isExpanded` to `false` in the preview to confirm only the title + chevron remain.)

- [ ] **Step 5: Commit** (only if the user has authorized committing)

```bash
git add Brackets/StandingsView.swift
git commit -m "Add shared standings table body and collapsible group card"
```

---

### Task 3: Rewire StandingsView (state, grouped + flat rendering) and remove old cards

**Files:**
- Modify: `Brackets/StandingsView.swift`

**Interfaces:**
- Consumes: `GroupStandingsCard`, `StandingsTableBody`, `StandingsTableRow` from Tasks 1–2; existing `TeamDetailView`, `Tiebreaker`, `StandingsResult`, `GroupStanding`.
- Produces: updated `StandingsView` behavior. Removes `StandingCard`, `StatColumn`, `AvgColumn`, `DiffColumn`.

- [ ] **Step 1: Add expansion state to `StandingsView`**

In `struct StandingsView`, add alongside the existing `@State` properties (after `selectedSubTab`):

```swift
    @State private var expandedGroups: Set<String> = []
    @State private var didInitExpansion = false
```

- [ ] **Step 2: Initialize expansion after a successful load**

In `loadStandings()`, replace the success body so the first group starts expanded (runs once):

```swift
        do {
            let loaded = try await APIService.shared.fetchStandings(for: tournament.id)
            bundle = loaded
            if !didInitExpansion, case .groups(let groups) = loaded.result, let first = groups.first {
                expandedGroups = [first.id]
                didInitExpansion = true
            }
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
```

- [ ] **Step 3: Add the toggle helper and the shared row builder**

Add these methods inside `StandingsView` (e.g. after `loadStandings()`):

```swift
    private func toggle(_ id: String) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            if expandedGroups.contains(id) {
                expandedGroups.remove(id)
            } else {
                expandedGroups.insert(id)
            }
        }
    }

    @ViewBuilder
    private func standingRow(index: Int, standing: TeamStanding) -> some View {
        NavigationLink {
            TeamDetailView(standing: standing, tournamentId: tournament.id, tournamentName: tournament.name, rank: index + 1)
        } label: {
            StandingsTableRow(
                position: index + 1,
                standing: standing,
                usesAverage: tournament.usesAverage,
                onTiebreakerTap: standing.tiebreaker.map { tb in { presentedTiebreaker = tb } }
            )
        }
        .buttonStyle(.plain)
    }
```

- [ ] **Step 4: Rewrite `standingsScroll` for the new layout**

Replace the entire `standingsScroll(_:)` function with:

```swift
    @ViewBuilder
    private func standingsScroll(_ result: StandingsResult) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                switch result {
                case .flat(let standings):
                    StandingsTableBody(
                        usesAverage: tournament.usesAverage,
                        standings: standings
                    ) { index, standing in
                        standingRow(index: index, standing: standing)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large)
                            .fill(AppTheme.Colors.cardBackground)
                    )
                    .padding(.horizontal, AppTheme.Layout.screenPadding)
                case .groups(let groups):
                    ForEach(groups) { group in
                        GroupStandingsCard(
                            title: group.name.capitalized,
                            usesAverage: tournament.usesAverage,
                            isExpanded: expandedGroups.contains(group.id),
                            onToggle: { toggle(group.id) },
                            standings: group.standings
                        ) { index, standing in
                            standingRow(index: index, standing: standing)
                        }
                        .padding(.horizontal, AppTheme.Layout.screenPadding)
                    }
                }
            }
            .padding(.top, AppTheme.Spacing.small)
            .padding(.bottom, AppTheme.Layout.large)
        }
    }
```

- [ ] **Step 5: Remove the old `standingsList` and per-team card types**

Delete the now-unused `standingsList(_:)` method from `StandingsView`, and delete the top-level `struct StandingCard`, `struct StatColumn`, `struct DiffColumn`, and `struct AvgColumn`. (Keep `AppTheme.RecordBadge` — it lives in `AppTheme.swift` and is unaffected.)

- [ ] **Step 6: Build and verify in Xcode**

Run: Build with **⌘B**.
Expected: Build succeeds with no references to `StandingCard`/`StatColumn`/`AvgColumn`/`DiffColumn`/`standingsList` remaining. Run the app (or the main `#Preview`) on a tournament with grouped standings: the **first group is expanded**, later groups collapsed; tapping a group header animates its table open/closed and rotates the chevron; tapping a team row pushes its detail page; the tiebreaker `info.circle` still opens the sheet. A flat-standings tournament shows a single always-visible table card.

- [ ] **Step 7: Commit** (only if the user has authorized committing)

```bash
git add Brackets/StandingsView.swift
git commit -m "Rework standings into collapsible table cards per group"
```

---

## Self-Review

**Spec coverage:**
- One card per group with table → Task 2 (`GroupStandingsCard`) + Task 3 wiring. ✔
- Column header `# EQUIPOS J G P FAV CON AVG` + data mapping → Task 1 (`StandingsTableHeader`, `StandingsTableRow`). ✔
- Collapsible title + chevron rotation + spring animation → Task 2 header button + Task 3 `toggle`. ✔
- First expanded / rest collapsed on load → Task 3 Step 2. ✔
- AVG green pill unsigned `%.3f`; DIF signed conditional on `usesAverage` → Task 1 (`AvgPill`/`DiffCell`, `StandingsTableRow`). ✔
- Row navigates to `TeamDetailView` with same args → Task 3 `standingRow`. ✔
- Tiebreaker `info.circle` preserved → Task 1 `StandingsTableRow` + Task 3 `onTiebreakerTap` wiring. ✔
- Flat case: same table, no collapse → Task 3 Step 4 `.flat` branch. ✔
- Drop `RecordBadge` from this view / remove old cells → Task 3 Step 5. ✔
- Champion tab / loading / error / empty / tiebreaker sheet unchanged → not modified. ✔

**Placeholder scan:** No TBD/TODO; all code blocks are complete. The only note is the preview initializer caveat (Task 1 Step 4), which is a verification aid, not implementation code.

**Type consistency:** `usesAverage`, `standings`, `rowBuilder(Int, TeamStanding)`, `isExpanded`, `onToggle`, `toggle(_:)`, `standingRow(index:standing:)`, `StandingsCol.*` names are consistent across Tasks 1–3.
