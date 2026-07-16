# "Ranking Final" Button + Final Ranking View — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a "Ranking Final" button pinned at the bottom of the Standings screen that opens a full-screen modal listing every team's final placement, from a new `ranking.json` endpoint.

**Architecture:** Add `RankingResponse`/`RankingEntry` models and `fetchRanking` to `APIService`; build a self-contained `RankingView` (given pre-fetched data) in a new file; wire the fetch, visibility gate, pinned button (`.safeAreaInset`), and `.fullScreenCover` into `StandingsView`. Tasks are ordered so every step leaves a compiling app: (1) models + API, (2) the modal view + button, (3) wire into `StandingsView`.

**Tech Stack:** Swift 5 / SwiftUI (iOS 17+), URLSession + `Codable`. No third-party deps.

## Global Constraints

- **No test target / no terminal build tools.** Per `CLAUDE.md`, this project has no unit-test target and builds only in Xcode. Verification for every task is: open `Brackets.xcodeproj`, build with ⌘B (expect **Build Succeeded**), and inspect the relevant SwiftUI `#Preview`. There are no `xcodebuild`/`pytest` commands.
- **New `.swift` files compile automatically** — the project uses Xcode file-system-synchronized groups (`objectVersion 77`, `PBXFileSystemSynchronizedRootGroup`); do NOT edit `project.pbxproj`.
- **Dark mode only**; accent lime `AppTheme.Colors.accent`. All UI text in Spanish.
- **Endpoint:** `{APIConfig.apiURL}/tournaments/{id}/ranking.json` (`apiURL` = `{baseURL}/api`).
- **"RESULTADO" column = `stage_label`** (NOT `result_label`, which does not exist in this payload).
- **Row id = `teamSeasonId`.** Ranking list is pre-sorted by `place`; do not re-sort.
- **Button visibility:** only when `available == true` AND `ranking` non-empty.
- **No export/PDF button.**
- **Commit messages** end with:
  `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`
- Do not commit until the user gives the go-ahead; the user's norm is "uncommitted unless authorized."

---

### Task 1: Ranking models + `fetchRanking` (`APIService.swift`)

Additive. Adds the decodable models and the fetch method. Nothing else references them yet, so the build stays green.

**Files:**
- Modify: `Brackets/APIService.swift` (add models after the `StandingsBundle` struct ~line 132; add `fetchRanking` immediately before `func fetchGames` ~line 570)

**Interfaces:**
- Consumes: `APIConfig.apiURL`, `APIConfig.baseURL`, `APIError`, `APIService.shared` (all existing).
- Produces:
  - `struct RankingResponse: Codable, Sendable` with `tournamentId: Int`, `tournamentName: String`, `available: Bool`, `ranking: [RankingEntry]`; a tolerant `init(from:)` and a memberwise `init(tournamentId:tournamentName:available:ranking:)`.
  - `struct RankingEntry: Codable, Sendable, Identifiable, Hashable` with `place: Int`, `teamId: Int`, `teamSeasonId: Int`, `teamName: String`, `teamLogo: String?`, `bracketName: String?`, `stageLabel: String?`, `var id: Int { teamSeasonId }`, `var fullImageURL: String?`.
  - `func fetchRanking(for tournamentId: Int) async throws -> RankingResponse` on `APIService`.

- [ ] **Step 1: Add the models**

In `Brackets/APIService.swift`, find the `StandingsBundle` struct:

```swift
struct StandingsBundle: Sendable {
    let result: StandingsResult
    let podiums: [BracketPodium]
    let classification: Classification?
}
```

Insert immediately **after** its closing brace:

```swift

// MARK: - Ranking (final placement across brackets)

struct RankingResponse: Codable, Sendable {
    let tournamentId: Int
    let tournamentName: String
    let available: Bool
    let ranking: [RankingEntry]

    enum CodingKeys: String, CodingKey {
        case tournamentId = "tournament_id"
        case tournamentName = "tournament_name"
        case available
        case ranking
    }

    init(tournamentId: Int, tournamentName: String, available: Bool, ranking: [RankingEntry]) {
        self.tournamentId = tournamentId
        self.tournamentName = tournamentName
        self.available = available
        self.ranking = ranking
    }

    // Tolerant: default available=false and ranking=[] if the API omits them.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        tournamentId = try c.decodeIfPresent(Int.self, forKey: .tournamentId) ?? 0
        tournamentName = try c.decodeIfPresent(String.self, forKey: .tournamentName) ?? ""
        available = try c.decodeIfPresent(Bool.self, forKey: .available) ?? false
        ranking = try c.decodeIfPresent([RankingEntry].self, forKey: .ranking) ?? []
    }
}

struct RankingEntry: Codable, Sendable, Identifiable, Hashable {
    let place: Int
    let teamId: Int
    let teamSeasonId: Int
    let teamName: String
    let teamLogo: String?
    let bracketName: String?
    let stageLabel: String?

    var id: Int { teamSeasonId }

    enum CodingKeys: String, CodingKey {
        case place
        case teamId = "team_id"
        case teamSeasonId = "team_season_id"
        case teamName = "team_name"
        case teamLogo = "team_logo"
        case bracketName = "bracket_name"
        case stageLabel = "stage_label"
    }

    // Same URL-building rule as PodiumEntry.fullImageURL.
    var fullImageURL: String? {
        guard let logo = teamLogo else { return nil }
        if logo.lowercased().hasPrefix("http://") || logo.lowercased().hasPrefix("https://") {
            return logo
        }
        let path = logo.hasPrefix("/") ? String(logo.dropFirst()) : logo
        return "\(APIConfig.baseURL)/\(path)"
    }
}
```

- [ ] **Step 2: Add the `fetchRanking` method**

In `Brackets/APIService.swift`, find this line (the start of the next method after `fetchStandings`):

```swift
    func fetchGames(for tournamentId: Int) async throws -> [Game] {
```

Insert immediately **before** it:

```swift
    func fetchRanking(for tournamentId: Int) async throws -> RankingResponse {
        guard let url = URL(string: "\(APIConfig.apiURL)/tournaments/\(tournamentId)/ranking.json") else {
            throw APIError.invalidURL
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw APIError.invalidResponse
        }
        return try JSONDecoder().decode(RankingResponse.self, from: data)
    }

```

- [ ] **Step 3: Verify build**

Open `Brackets.xcodeproj` and build (⌘B). Expected: **Build Succeeded** (additive; no existing call sites changed).

- [ ] **Step 4: Commit**

```bash
git add Brackets/APIService.swift
git commit -m "feat: add ranking endpoint models and fetch

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: `RankingView` modal + `RankingButton` (`RankingView.swift`, new file)

Self-contained view given a `RankingResponse` from Task 1. Compiles and previews independently; not yet wired into Standings.

**Files:**
- Create: `Brackets/RankingView.swift`

**Interfaces:**
- Consumes: `RankingResponse`, `RankingEntry` (Task 1); `AppTheme`, `StandingsSurface` (existing).
- Produces:
  - `struct RankingView: View` — `init(response: RankingResponse)`.
  - `struct RankingButton: View` — `init(action: @escaping () -> Void)`.

- [ ] **Step 1: Create the file**

Create `Brackets/RankingView.swift` with exactly:

```swift
//
//  RankingView.swift
//  Brackets
//

import SwiftUI

/// Fixed column widths so the header row and every ranking row line up.
private enum RankingCol {
    static let place: CGFloat = 28
    static let logo: CGFloat = 28
    static let bracket: CGFloat = 64
    static let result: CGFloat = 96
    static let hSpacing: CGFloat = 10
    static let rowVPadding: CGFloat = 12
}

/// Full-screen final ranking list. Receives pre-fetched data — no loading state.
struct RankingView: View {
    let response: RankingResponse
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AppTheme.Colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                columnHeader
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(response.ranking.enumerated()), id: \.element.id) { index, entry in
                            RankingRow(entry: entry, striped: index.isMultiple(of: 2))
                        }
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("\(response.tournamentName) — Ranking Final")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AppTheme.Colors.primaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 8)
            Button {
                dismiss()
            } label: {
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 36, height: 36)
                    .overlay {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppTheme.Colors.primaryText)
                    }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AppTheme.Layout.screenPadding)
        .padding(.top, 12)
        .padding(.bottom, 16)
    }

    private var columnHeader: some View {
        HStack(spacing: RankingCol.hSpacing) {
            Text("#")
                .frame(width: RankingCol.place, alignment: .leading)
            Text("EQUIPO")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("BRACKET")
                .frame(width: RankingCol.bracket, alignment: .leading)
            Text("RESULTADO")
                .frame(width: RankingCol.result, alignment: .leading)
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(AppTheme.Colors.secondaryText)
        .padding(.horizontal, AppTheme.Layout.screenPadding)
        .padding(.vertical, 10)
        .background(StandingsSurface.header)
    }
}

private struct RankingRow: View {
    let entry: RankingEntry
    let striped: Bool

    var body: some View {
        HStack(spacing: RankingCol.hSpacing) {
            Text("\(entry.place)")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .frame(width: RankingCol.place, alignment: .leading)

            HStack(spacing: 8) {
                logo
                Text(entry.teamName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.primaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(entry.bracketName ?? "")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.Colors.primaryText)
                .frame(width: RankingCol.bracket, alignment: .leading)

            Text(entry.stageLabel ?? "")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.Colors.primaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .frame(width: RankingCol.result, alignment: .leading)
        }
        .padding(.horizontal, AppTheme.Layout.screenPadding)
        .padding(.vertical, RankingCol.rowVPadding)
        .background(striped ? Color(white: 0.13) : StandingsSurface.rows)
    }

    @ViewBuilder
    private var logo: some View {
        ZStack {
            Circle().fill(Color(white: 0.18))
            if let urlString = entry.fullImageURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        initials
                    }
                }
                .clipShape(Circle())
            } else {
                initials
            }
        }
        .frame(width: RankingCol.logo, height: RankingCol.logo)
        .clipShape(Circle())
    }

    private var initials: some View {
        Text(String(entry.teamName.prefix(2)).uppercased())
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.white)
    }
}

/// Full-width navy pill button that opens the final ranking.
struct RankingButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 15, weight: .semibold))
                Text("Ranking Final")
                    .font(.system(size: 15, weight: .bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(red: 0.10, green: 0.12, blue: 0.30))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview("Ranking view") {
    RankingView(response: RankingResponse(
        tournamentId: 45,
        tournamentName: "Femenil 2008-09",
        available: true,
        ranking: [
            RankingEntry(place: 1, teamId: 417, teamSeasonId: 890, teamName: "Gladiadores Valle", teamLogo: nil, bracketName: "Gold", stageLabel: "Campeón"),
            RankingEntry(place: 2, teamId: 436, teamSeasonId: 909, teamName: "Pingüinos Sierra", teamLogo: nil, bracketName: "Gold", stageLabel: "Subcampeón"),
            RankingEntry(place: 3, teamId: 453, teamSeasonId: 926, teamName: "Cometas Azteca", teamLogo: nil, bracketName: "Gold", stageLabel: "3er Lugar"),
            RankingEntry(place: 9, teamId: 413, teamSeasonId: 886, teamName: "Águilas Continental", teamLogo: nil, bracketName: "Silver", stageLabel: "Campeón"),
            RankingEntry(place: 17, teamId: 500, teamSeasonId: 950, teamName: "Rayos Valle", teamLogo: nil, bracketName: "Silver", stageLabel: "Octavos de Final"),
            RankingEntry(place: 25, teamId: 420, teamSeasonId: 893, teamName: "Cometas Cumbres", teamLogo: nil, bracketName: "Bronze", stageLabel: "Campeón"),
        ]
    ))
}

#Preview("Ranking button") {
    ZStack {
        Color.black.ignoresSafeArea()
        RankingButton { }
            .padding()
    }
}
```

- [ ] **Step 2: Verify build and previews**

Build (⌘B). Expected: **Build Succeeded**.
Open the **"Ranking view"** preview: 6 rows, columns (#, EQUIPO, BRACKET, RESULTADO) aligned with the header, alternating row shading, ✕ button top-right, title "Femenil 2008-09 — Ranking Final".
Open the **"Ranking button"** preview: full-width navy pill with trophy + "Ranking Final".

- [ ] **Step 3: Commit**

```bash
git add Brackets/RankingView.swift
git commit -m "feat: add final ranking modal and button views

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: Wire button + fetch + presentation into `StandingsView.swift`

Adds the ranking fetch, the visibility gate, the pinned button, and the modal presentation. Consumes Tasks 1 and 2. After this task the feature works end-to-end.

**Files:**
- Modify: `Brackets/StandingsView.swift` (add `StandingsLayout` near `StandingsCol` ~line 27; state ~line 253; visibility computed prop ~line 266; body modifiers ~line 320-323)

**Interfaces:**
- Consumes: `APIService.shared.fetchRanking(for:)`, `RankingResponse`, `RankingView`, `RankingButton`.
- Produces: no new outward interface.

- [ ] **Step 1: Add the `StandingsLayout` clearance constant**

In `Brackets/StandingsView.swift`, find the `StandingsCol` enum (starts `enum StandingsCol {`). Insert **before** it:

```swift
/// Layout constants for the Standings screen.
enum StandingsLayout {
    /// Bottom clearance so the pinned "Ranking Final" button sits above the
    /// container's floating CustomTabBar (TabButton 52 + bar padding 16 + bottom
    /// padding 10 ≈ 78, plus a gap). Tune on-device in Xcode if needed.
    static let tabBarClearance: CGFloat = 84
}

```

- [ ] **Step 2: Add ranking state**

Find:

```swift
    @State private var didInitSubTab = false
    @State private var selectedPodiumName: String?
```

Replace with:

```swift
    @State private var didInitSubTab = false
    @State private var selectedPodiumName: String?
    @State private var ranking: RankingResponse?
    @State private var showRanking = false
```

- [ ] **Step 3: Add the visibility computed property**

Find:

```swift
    private var hasClassificationTab: Bool {
        !(bundle?.classification?.teams.isEmpty ?? true)
    }
```

Insert immediately **after** it:

```swift

    private var showsRankingButton: Bool {
        guard let ranking else { return false }
        return ranking.available && !ranking.ranking.isEmpty
    }
```

- [ ] **Step 4: Pin the button and present the modal**

Find the end of `body` (the existing `.task` block and the brace that closes `body`):

```swift
        .task {
            await loadStandings()
        }
    }
```

Replace with:

```swift
        .task {
            await loadStandings()
        }
        .task {
            ranking = try? await APIService.shared.fetchRanking(for: tournament.id)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if showsRankingButton {
                RankingButton { showRanking = true }
                    .padding(.horizontal, AppTheme.Layout.screenPadding)
                    .padding(.top, AppTheme.Spacing.small)
                    .padding(.bottom, StandingsLayout.tabBarClearance)
                    .frame(maxWidth: .infinity)
            }
        }
        .fullScreenCover(isPresented: $showRanking) {
            if let ranking {
                RankingView(response: ranking)
            }
        }
    }
```

- [ ] **Step 5: Verify build and behavior**

Build (⌘B). Expected: **Build Succeeded**.
Run the app against a finished tournament (e.g. one whose ranking endpoint returns `available: true`). On the **Standings** tab:
- The "Ranking Final" button appears pinned above the floating tab bar, clearing it (check a notch and a non-notch simulator; adjust `StandingsLayout.tabBarClearance` if the gap is wrong).
- Tapping it presents the full ranking list; ✕ (top-right) returns to Standings.
On an in-progress tournament (ranking `available: false` or empty): no button appears.

- [ ] **Step 6: Commit**

```bash
git add Brackets/StandingsView.swift
git commit -m "feat: show Ranking Final button and modal on Standings

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Manual QA (after Task 3)

1. Finished tournament → button visible on Standings, clears the tab bar, opens the list, ✕ closes it.
2. Long team name truncates; "Octavos de Final" wraps/scales without breaking the columns.
3. In-progress / `available:false` / empty ranking → no button.
4. Button does not overlap the tab bar on both a notch and a non-notch device.

## Self-Review Notes

- **Spec coverage:** endpoint + models (Task 1) ✓; `stage_label`→RESULTADO, `id=teamSeasonId`, no re-sort (Task 1/2) ✓; table columns + logo fallback + ✕ close + title (Task 2) ✓; fetch availability gate (Task 3, `showsRankingButton`) ✓; `.safeAreaInset` pinned button + clearance constant (Task 3) ✓; `.fullScreenCover` with pre-fetched data (Task 3) ✓; no export button ✓.
- **Type consistency:** `RankingResponse`/`RankingEntry` property names and the memberwise `init(tournamentId:tournamentName:available:ranking:)` used in the Task 2 preview match Task 1; `RankingEntry(place:teamId:teamSeasonId:teamName:teamLogo:bracketName:stageLabel:)` synthesized memberwise init matches the declared stored properties in order; `RankingButton(action:)` and `RankingView(response:)` signatures match their Task 3 call sites; `StandingsLayout.tabBarClearance` defined in Task 3 Step 1 and used in Step 4.
- **No placeholders:** every code step shows full code; verification is Xcode build + named previews + manual (no fabricated CLI commands, per the no-test-target constraint). The clearance constant (84) and navy button color are concrete initial values with an on-device tuning step, not placeholders.
