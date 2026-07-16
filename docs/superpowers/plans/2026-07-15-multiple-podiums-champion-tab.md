# Multiple Podiums in the "Campeón" Tab — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Display one per-bracket podium at a time in the "Campeón" tab, selected via a Gold/Silver/Bronze pill carousel, driven by the new `podiums` array from the standings endpoint.

**Architecture:** Add a `BracketPodium` decodable model for the new `podiums` array, thread it through `StandingsResponse` → `StandingsBundle`, then reuse the existing `ChipCarousel` selector and `ChampionPanel`/`PodiumCard` visuals in `StandingsView`. The old singular `podium` key is removed. Work is ordered so every task leaves a compiling app: (1) additive model + plumbing, (2) view refactor to consume `podiums`, (3) delete the now-dead singular `podium`.

**Tech Stack:** Swift 5 / SwiftUI (iOS 17+), URLSession + `Codable`. No third-party deps.

## Global Constraints

- **No test target / no terminal build tools.** Per `CLAUDE.md`, this project has no unit-test target and builds only in Xcode. Verification for every task is: open `Brackets.xcodeproj`, build with ⌘B (expect **Build Succeeded**), and inspect the relevant SwiftUI `#Preview` in the Xcode canvas. There are no `xcodebuild`/`pytest` commands to run.
- **Dark mode only**, accent color lime `#C7F24A` (`AppTheme.Colors.accent`). All UI text in Spanish.
- **Type name:** the new model is `BracketPodium` (approved).
- **Panel subtitle** uses `tournament.name` (podium items carry no `tournament_name`).
- **Default landing tab** is Campeón whenever `podiums` is non-empty.
- **Commit messages** end with:
  `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`
- Do not commit until the user has given the go-ahead to execute; commit steps below run during execution.

---

### Task 1: Add `BracketPodium` model and thread `podiums` through the standings layer (additive)

Additive only — the existing `podium` field stays for now so the app keeps compiling. This task makes `bundle.podiums` available to the view layer.

**Files:**
- Modify: `Brackets/APIService.swift` (`StandingsResponse` ~36-48; add `BracketPodium` near `Podium` ~122-134; `StandingsBundle` ~136-140; `fetchStandings` constructions ~513, 516, 520, 527)

**Interfaces:**
- Consumes: existing `PodiumEntry` (unchanged), `StandingsResponse`, `StandingsBundle`.
- Produces:
  - `struct BracketPodium: Codable, Sendable, Hashable, Identifiable` with `bracketId: Int`, `position: Int`, `name: String`, `type: String?`, `typeLabel: String?`, `first: PodiumEntry`, `second: PodiumEntry?`, `third: PodiumEntry?`, `var id: Int { bracketId }`.
  - `StandingsResponse.podiums: [BracketPodium]?`
  - `StandingsBundle.podiums: [BracketPodium]` (non-optional).

- [ ] **Step 1: Add the `BracketPodium` struct**

In `Brackets/APIService.swift`, immediately after the existing `struct Podium { … }` (ends ~line 134), add:

```swift
/// One per-bracket podium (e.g. Gold / Silver / Bronze) from the standings
/// endpoint's `podiums` array. Unlike the legacy singular `podium`, these carry
/// no `tournament_name` — the champion panel supplies it from the tournament.
struct BracketPodium: Codable, Sendable, Hashable, Identifiable {
    let bracketId: Int
    let position: Int
    let name: String
    let type: String?
    let typeLabel: String?
    let first: PodiumEntry
    let second: PodiumEntry?
    let third: PodiumEntry?

    var id: Int { bracketId }

    enum CodingKeys: String, CodingKey {
        case position, name, type, first, second, third
        case bracketId = "bracket_id"
        case typeLabel = "type_label"
    }
}
```

- [ ] **Step 2: Add `podiums` to `StandingsResponse`**

Replace the `StandingsResponse` struct (~36-48) with:

```swift
// Response wrapper for standings
struct StandingsResponse: Codable, Sendable {
    let standings: [TeamStanding]?
    let groupStandings: [GroupStanding]?
    let podium: Podium?
    let podiums: [BracketPodium]?
    let classification: Classification?

    enum CodingKeys: String, CodingKey {
        case standings
        case groupStandings = "group_standings"
        case podium
        case podiums
        case classification
    }
}
```

- [ ] **Step 3: Add `podiums` to `StandingsBundle`**

Replace the `StandingsBundle` struct (~136-140) with:

```swift
struct StandingsBundle: Sendable {
    let result: StandingsResult
    let podium: Podium?
    let podiums: [BracketPodium]
    let classification: Classification?
}
```

- [ ] **Step 4: Pass `podiums` into every `StandingsBundle` construction**

In `fetchStandings`, update the four `StandingsBundle(...)` calls. The three inside the wrapped-response branch take the decoded `podiums`; the direct-array fallback gets `[]`.

Wrapped-response branch (~508-522) becomes:

```swift
            // Try to decode as wrapped response first
            if let response = try? decoder.decode(StandingsResponse.self, from: data) {
                if let groups = response.groupStandings, !groups.isEmpty {
                    // Single group named "DEFAULT" means no real groups — treat as flat
                    if groups.count == 1, groups[0].name.uppercased() == "DEFAULT" {
                        print("✅ Decoded standings as flat (single DEFAULT group)")
                        return StandingsBundle(result: .flat(groups[0].standings), podium: response.podium, podiums: response.podiums ?? [], classification: response.classification)
                    }
                    print("✅ Decoded standings as group standings")
                    return StandingsBundle(result: .groups(groups), podium: response.podium, podiums: response.podiums ?? [], classification: response.classification)
                }
                if let standings = response.standings, !standings.isEmpty {
                    print("✅ Decoded standings as wrapped response")
                    return StandingsBundle(result: .flat(standings), podium: response.podium, podiums: response.podiums ?? [], classification: response.classification)
                }
            }
```

Direct-array fallback (~525-528) becomes:

```swift
            // Fallback: Try to decode as direct array
            if let standings = try? decoder.decode([TeamStanding].self, from: data) {
                print("✅ Decoded standings as direct array")
                return StandingsBundle(result: .flat(standings), podium: nil, podiums: [], classification: nil)
            }
```

- [ ] **Step 5: Verify build**

Open `Brackets.xcodeproj` in Xcode and build (⌘B).
Expected: **Build Succeeded** (purely additive; no call sites broke).

- [ ] **Step 6: Commit**

```bash
git add Brackets/APIService.swift
git commit -m "feat: decode podiums array in standings response

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: Consume `podiums` in the Campeón tab (gating, default tab, selector, `ChampionPanel` refactor)

Wires the feature end-to-end. Consumes `bundle.podiums` from Task 1. After this task the app is functional; the legacy `podium` field is still present but unused (removed in Task 3).

**Files:**
- Modify: `Brackets/StandingsView.swift` (state/init ~245-260; `hasChampionTab` ~258-260; `body` champion case ~293-308; `loadStandings` ~361-381; `ChampionPanel` ~448-497; add a `championTab` helper and a `#Preview`)

**Interfaces:**
- Consumes: `StandingsBundle.podiums: [BracketPodium]`, `BracketPodium` (`name`, `position`, `first/second/third`), existing `ChipCarousel<String>`, existing `PodiumCard`.
- Produces:
  - `ChampionPanel(podium: BracketPodium, tournamentName: String)` — new signature.
  - `@ViewBuilder private func championTab(_ bundle: StandingsBundle) -> some View`.

- [ ] **Step 1: Add selector state and reset init default**

In `StandingsView`, replace the state block + `init` + `hasChampionTab` (~245-260) with:

```swift
    @State private var bundle: StandingsBundle?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var presentedTiebreaker: Tiebreaker?
    @State private var selectedSubTab: StandingsSubTab
    @State private var expandedGroups: Set<String> = []
    @State private var didInitExpansion = false
    @State private var didInitSubTab = false
    @State private var selectedPodiumName: String?

    init(tournament: Tournament) {
        self.tournament = tournament
        _selectedSubTab = State(initialValue: .standings)
    }

    private var hasChampionTab: Bool {
        !(bundle?.podiums.isEmpty ?? true)
    }
```

- [ ] **Step 2: Route the champion case through a helper**

In `body`, replace the `.champion` case (~294-299) so the whole switch reads:

```swift
                    switch selectedSubTab {
                    case .champion:
                        championTab(bundle)
                    case .classification:
                        if let classification = bundle.classification {
                            ClassificationView(classification: classification)
                        } else {
                            standingsScroll(bundle.result)
                        }
                    case .standings:
                        standingsScroll(bundle.result)
                    }
```

- [ ] **Step 3: Add the `championTab` helper**

Add this method to `StandingsView` (place it right before `standingsScroll` ~327):

```swift
    @ViewBuilder
    private func championTab(_ bundle: StandingsBundle) -> some View {
        let podiums = bundle.podiums.sorted { $0.position < $1.position }
        if let selected = podiums.first(where: { $0.name == selectedPodiumName }) ?? podiums.first {
            VStack(spacing: 0) {
                ChipCarousel(items: podiums.map(\.name), label: { $0 }, selected: $selectedPodiumName)
                    .padding(.bottom, AppTheme.Spacing.medium)
                ChampionPanel(podium: selected, tournamentName: tournament.name)
            }
        } else {
            standingsScroll(bundle.result)
        }
    }
```

- [ ] **Step 4: Initialize selection and default tab on load**

In `loadStandings`, replace the body between `bundle = loaded` and `isLoading = false` (~367-375) with:

```swift
            bundle = loaded
            if !didInitExpansion, case .groups(let groups) = loaded.result {
                expandedGroups = Set(groups.prefix(2).map(\.id))
                didInitExpansion = true
            }
            if selectedPodiumName == nil {
                selectedPodiumName = loaded.podiums.sorted { $0.position < $1.position }.first?.name
            }
            // Default to Campeón when podiums exist; otherwise fall back to Grupos.
            if !didInitSubTab {
                selectedSubTab = availableTabs.first ?? .standings
                didInitSubTab = true
            } else if !availableTabs.contains(selectedSubTab) {
                selectedSubTab = .standings
            }
```

- [ ] **Step 5: Refactor `ChampionPanel` to `BracketPodium` + `tournamentName`**

Change the `ChampionPanel` declaration (~448-449) to:

```swift
struct ChampionPanel: View {
    let podium: BracketPodium
    let tournamentName: String
```

Then in its `body`, replace the tournament-name line (~466) so the title block reads:

```swift
                    Text(podium.first.teamName.uppercased())
                        .font(.system(size: 42, weight: .heavy))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.5)
                        .multilineTextAlignment(.center)
                    Text("CAMPEÓN")
                        .font(.system(size: 42, weight: .heavy))
                        .foregroundStyle(.white)

                    Text(tournamentName.uppercased())
                        .font(.system(size: 13, weight: .semibold))
                        .tracking(2)
                        .foregroundStyle(Color(white: 0.5))
                        .padding(.top, 14)
                        .multilineTextAlignment(.center)
```

Everything else in `ChampionPanel` (the podium `HStack` using `podium.first/second/third`) and all of `PodiumCard` are unchanged — `BracketPodium` exposes the same `first/second/third` properties as the old `Podium`.

- [ ] **Step 6: Add a multi-podium `#Preview`**

At the end of `Brackets/StandingsView.swift`, append a preview that exercises the selector + panel together:

```swift
#Preview("Champion — multiple podiums") {
    struct Wrap: View {
        let podiums: [BracketPodium] = [
            BracketPodium(
                bracketId: 43, position: 1, name: "Gold", type: "quarterfinals", typeLabel: "Cuartos",
                first: PodiumEntry(place: 1, teamId: 417, teamSeasonId: 890, teamName: "Gladiadores Valle", teamLogo: nil),
                second: PodiumEntry(place: 2, teamId: 436, teamSeasonId: 909, teamName: "Pingüinos Sierra", teamLogo: nil),
                third: PodiumEntry(place: 3, teamId: 453, teamSeasonId: 926, teamName: "Cometas Azteca", teamLogo: nil)
            ),
            BracketPodium(
                bracketId: 44, position: 2, name: "Silver", type: "octavos", typeLabel: "Octavos de Final",
                first: PodiumEntry(place: 1, teamId: 413, teamSeasonId: 886, teamName: "Águilas Continental", teamLogo: nil),
                second: PodiumEntry(place: 2, teamId: 423, teamSeasonId: 896, teamName: "Titanes Pacífico", teamLogo: nil),
                third: PodiumEntry(place: 3, teamId: 445, teamSeasonId: 918, teamName: "Osos Monterrey", teamLogo: nil)
            ),
            BracketPodium(
                bracketId: 45, position: 3, name: "Bronze", type: "octavos", typeLabel: "Octavos de Final",
                first: PodiumEntry(place: 1, teamId: 420, teamSeasonId: 893, teamName: "Cometas Cumbres", teamLogo: nil),
                second: PodiumEntry(place: 2, teamId: 421, teamSeasonId: 894, teamName: "Gladiadores Monterrey", teamLogo: nil),
                third: PodiumEntry(place: 3, teamId: 456, teamSeasonId: 929, teamName: "Gavilanes Guadalupe", teamLogo: nil)
            ),
        ]
        @State private var selected: String? = "Gold"
        var current: BracketPodium { podiums.first { $0.name == selected } ?? podiums[0] }
        var body: some View {
            VStack(spacing: 0) {
                ChipCarousel(items: podiums.map(\.name), label: { $0 }, selected: $selected)
                    .padding(.bottom, 12)
                ChampionPanel(podium: current, tournamentName: "Elite Campeonato Nacional 2026")
            }
        }
    }
    return ZStack { Color.black.ignoresSafeArea(); Wrap() }
}
```

- [ ] **Step 7: Verify build and previews**

Open `Brackets.xcodeproj` and build (⌘B). Expected: **Build Succeeded**.
Open the canvas for the **"Champion — multiple podiums"** preview. Expected:
- Gold / Silver / Bronze pill row, Gold selected (lime border).
- Podium shows Gold's three teams; tapping Silver/Bronze swaps all three cards and the "CAMPEÓN" title.

- [ ] **Step 8: Commit**

```bash
git add Brackets/StandingsView.swift
git commit -m "feat: show per-bracket podiums with selector in Campeón tab

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: Remove the dead singular `podium`

`podiums` now drives everything; the legacy singular `podium` is unused. Delete it so there is one source of truth.

**Files:**
- Modify: `Brackets/APIService.swift` (`struct Podium` ~122-134; `StandingsResponse.podium` + CodingKey; `StandingsBundle.podium`; the four `fetchStandings` constructions)

**Interfaces:**
- Consumes: nothing new.
- Produces: `StandingsResponse` and `StandingsBundle` no longer have a `podium` property; `struct Podium` no longer exists.

- [ ] **Step 1: Delete the `Podium` struct**

In `Brackets/APIService.swift`, delete the entire `struct Podium: Codable, Sendable, Hashable { … }` block (~122-134). Keep `PodiumEntry` and `BracketPodium`.

- [ ] **Step 2: Remove `podium` from `StandingsResponse`**

Replace `StandingsResponse` with:

```swift
// Response wrapper for standings
struct StandingsResponse: Codable, Sendable {
    let standings: [TeamStanding]?
    let groupStandings: [GroupStanding]?
    let podiums: [BracketPodium]?
    let classification: Classification?

    enum CodingKeys: String, CodingKey {
        case standings
        case groupStandings = "group_standings"
        case podiums
        case classification
    }
}
```

- [ ] **Step 3: Remove `podium` from `StandingsBundle`**

Replace `StandingsBundle` with:

```swift
struct StandingsBundle: Sendable {
    let result: StandingsResult
    let podiums: [BracketPodium]
    let classification: Classification?
}
```

- [ ] **Step 4: Drop the `podium:` argument from all constructions**

In `fetchStandings`, remove `podium: …,` from each `StandingsBundle(...)` call. The wrapped-response branch becomes:

```swift
            // Try to decode as wrapped response first
            if let response = try? decoder.decode(StandingsResponse.self, from: data) {
                if let groups = response.groupStandings, !groups.isEmpty {
                    // Single group named "DEFAULT" means no real groups — treat as flat
                    if groups.count == 1, groups[0].name.uppercased() == "DEFAULT" {
                        print("✅ Decoded standings as flat (single DEFAULT group)")
                        return StandingsBundle(result: .flat(groups[0].standings), podiums: response.podiums ?? [], classification: response.classification)
                    }
                    print("✅ Decoded standings as group standings")
                    return StandingsBundle(result: .groups(groups), podiums: response.podiums ?? [], classification: response.classification)
                }
                if let standings = response.standings, !standings.isEmpty {
                    print("✅ Decoded standings as wrapped response")
                    return StandingsBundle(result: .flat(standings), podiums: response.podiums ?? [], classification: response.classification)
                }
            }
```

The direct-array fallback becomes:

```swift
            // Fallback: Try to decode as direct array
            if let standings = try? decoder.decode([TeamStanding].self, from: data) {
                print("✅ Decoded standings as direct array")
                return StandingsBundle(result: .flat(standings), podiums: [], classification: nil)
            }
```

- [ ] **Step 5: Verify build**

Build in Xcode (⌘B). Expected: **Build Succeeded** with no "unused"/"cannot find 'Podium'" errors. If the compiler flags a lingering `Podium` or `.podium` reference, that reference was missed — remove it (there should be none outside `APIService.swift`; `StatsLeadersView`'s `podiumView` is unrelated).

- [ ] **Step 6: Commit**

```bash
git add Brackets/APIService.swift
git commit -m "refactor: drop legacy singular podium key from standings

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Manual QA (after Task 3)

Run the app in Xcode against real data and confirm:

1. **Multi-bracket tournament** — Campeón tab is the default landing tab; Gold/Silver/Bronze selector shows; switching chips swaps the three podium cards.
2. **Single-podium tournament** — exactly one chip renders and its podium shows.
3. **No `podiums`** — no Campeón tab; the view lands on Grupos.
4. **Podium missing 2nd/3rd** — the single first-place card renders centered (existing spacer handling).

## Self-Review Notes

- **Spec coverage:** model (Task 1) ✓; gating decoupled from `winner` (Task 2, Step 1) ✓; default tab = Campeón (Task 2, Step 4) ✓; always-show selector (Task 2, Step 3 — no count guard) ✓; subtitle uses `tournament.name` (Task 2, Step 5) ✓; drop singular `podium` (Task 3) ✓; preview (Task 2, Step 6) ✓.
- **Type consistency:** `BracketPodium` fields/`CodingKeys` identical across Tasks 1 and 3; `ChampionPanel(podium:tournamentName:)` label matches its call in `championTab`; `ChipCarousel<String>` usage matches `BracketView`'s existing pattern; `PodiumEntry` init in the preview matches its declared properties (`place, teamId, teamSeasonId, teamName, teamLogo`).
- **No placeholders:** every code step shows full code; verification is Xcode build + named preview (no fabricated CLI commands, per the no-test-target constraint).
