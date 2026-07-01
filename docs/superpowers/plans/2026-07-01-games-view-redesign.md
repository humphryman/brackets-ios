# Games View Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign the Games list to match the mockups — top Próximos/Resultados tab (no "Todos"), a scrollable group/bracket chip carousel with overflow arrows, per-date headers with a game count, and a unified dark card with a Final/Semifinal top banner, green location row, and stage/group tags.

**Architecture:** Add `group`/`bracket` to the `Game` model (already present in the API JSON) plus a `brackets` ordering list on `GamesResponse`. Rebuild the card (`GameCard`/`TeamSection`/`CenterSection`) and add a `GroupFilterCarousel` + `GameGroupChip`, then rewire `GamesListView` filtering/state. Built bottom-up so each task compiles.

**Tech Stack:** SwiftUI (iOS 17+), pure Swift, URLSession, `AppTheme` tokens. No third-party deps.

## Global Constraints

- **No terminal build/test tooling** — verify in **Xcode**: build **⌘B** and inspect each component's **SwiftUI `#Preview`**. No XCTest step.
- **Dark mode only**; accent lime `AppTheme.Colors.accent` (`#a3ff12`); UI text in Spanish; locale `es_MX`; dates use `AppConfig.DateTime.apiTimeZone`.
- **Group source:** games JSON has `"group": "Grupo N"` (null for playoffs) and `"bracket": "Playoffs"/"Playoffs 2"/…` (null for regular). Top-level `"brackets"` array orders bracket chips.
- **Top filter:** remove `.all` ("Todos"). Keep `.upcoming` ("Próximos"), `.completed` ("Resultados"), and `.live` ("En Vivo") only when live games exist.
- **Group carousel:** chips = groups natural-sorted (`Grupo 1,2,…,13`) then bracket chips; **exactly one chip always selected** (no "Todos"); overflow arrows.
- **Date header:** `"Jueves, 18 de Junio"` (weekday + month capitalized, "de" lowercase) + `"N Juegos"` badge (`"1 Juego"` singular).
- **Card banners:** Final → lime `accent` fill + black `accentText`; Semifinal → blue `Color(red: 0.23, green: 0.21, blue: 0.90)` + white. No banner otherwise. When a banner shows, the redundant gray stage tag is suppressed.
- **Tags:** left gray stage pill `Color(white: 0.2)` (`stage.capitalized`), right purple group/bracket pill `Color(red: 0.45, green: 0.31, blue: 0.82)` (`game.group ?? game.bracket`).
- Do **not** run `git commit` unless the executor is explicitly authorized; commit steps are written for completeness — leave changes uncommitted otherwise.

---

## File Structure

- **Modify `Brackets/Game.swift`:** add `Game.group`, `Game.bracket`; add `BracketInfo`; add `GamesResponse.brackets`.
- **Modify `Brackets/GamesListView.swift`:** redesign `GameCard`/`TeamSection`/`CenterSection` + `GameCardPalette`; add `GameGroupChip` + `GroupFilterCarousel` (+ preference keys); rewire `GameFilter`, filtering/state, date header.
- **Unchanged:** `LiveGameCard`, navigation destinations, `VenueLabel` (reused from `GameDetail.swift`).

---

### Task 1: Model — group, bracket, and bracket ordering

**Files:**
- Modify: `Brackets/Game.swift`

**Interfaces:**
- Produces: `Game.group: String?`, `Game.bracket: String?`; `struct BracketInfo { name: String; position: Int?; typeLabel: String? }`; `GamesResponse.brackets: [BracketInfo]?`.
- Note: `Game`'s synthesized **memberwise init** gains trailing `group:` and `bracket:` params (order: `id, gameTime, stage, bracketId, venue, isLive, period, teamStats, group, bracket`; `isLive`/`period` keep defaults). Used by later previews.

- [ ] **Step 1: Add the stored properties and coding keys to `Game`**

In `struct Game`, add after `let teamStats: [TeamStat]?`:

```swift
    let group: String?
    let bracket: String?
```

In `enum CodingKeys` (inside `Game`), add after `case teamStats = "team_stats"`:

```swift
        case group
        case bracket
```

- [ ] **Step 2: Decode the new fields**

In `extension Game: Codable`'s `init(from:)`, add after the `teamStats = …` line (before the venue block):

```swift
        group = try container.decodeIfPresent(String.self, forKey: .group)
        bracket = try container.decodeIfPresent(String.self, forKey: .bracket)
```

- [ ] **Step 3: Add `BracketInfo` and `GamesResponse.brackets`**

In `struct GamesResponse`, add the property (after `let games: [DateGroup]`):

```swift
    let brackets: [BracketInfo]?
```

Add `case brackets` to `GamesResponse`'s `CodingKeys` (which currently lists only `case games`):

```swift
    enum CodingKeys: String, CodingKey {
        case games
        case brackets
    }
```

Add this type just above `struct GamesResponse` (top level):

```swift
struct BracketInfo: Codable, Sendable {
    let name: String
    let position: Int?
    let typeLabel: String?

    enum CodingKeys: String, CodingKey {
        case name, position
        case typeLabel = "type_label"
    }
}
```

- [ ] **Step 4: Build and sanity-check in Xcode**

Run: **⌘B** (scheme `Brackets`).
Expected: builds. `GamesResponse`'s synthesized `Codable` decodes `brackets` when present and tolerates its absence (optional). The Games tab still loads exactly as before (new fields simply populate). No preview needed for this task.

- [ ] **Step 5: Commit** (only if authorized)

```bash
git add Brackets/Game.swift
git commit -m "Add group, bracket, and bracket ordering to Game model"
```

---

### Task 2: Card redesign — GameCard, TeamSection, CenterSection

**Files:**
- Modify: `Brackets/GamesListView.swift`

**Interfaces:**
- Consumes: `Game.group`, `Game.bracket` (Task 1); `VenueLabel(venue:)` from `GameDetail.swift`; `AppConfig.DateTime.apiTimeZone`.
- Produces: redesigned `GameCard(game:)`, `TeamSection(teamName:isWinner:imageURL:)`, `CenterSection(game:)`, and `private enum GameCardPalette`. Signatures used by `GamesListView` in Task 4.

- [ ] **Step 1: Add the card palette**

Add near the top of `GamesListView.swift` (after the `import SwiftUI` / `DateFormatter` extension, before `enum GameFilter`):

```swift
/// Colors specific to the redesigned game card.
private enum GameCardPalette {
    static let cardBackground = Color(white: 0.11)
    static let semifinalBanner = Color(red: 0.23, green: 0.21, blue: 0.90)
    static let stageTagFill = Color(white: 0.2)
    static let groupTagFill = Color(red: 0.45, green: 0.31, blue: 0.82)
}
```

- [ ] **Step 2: Replace `GameCard` with the new layout**

Replace the entire existing `struct GameCard: View { … }` (the finished/upcoming card, NOT `LiveGameCard`) with:

```swift
/// Unified game card: optional Final/Semifinal banner, teams, score/time, location, tags.
struct GameCard: View {
    let game: Game

    private var isFinal: Bool { game.stage?.lowercased() == "final" }
    private var isSemifinal: Bool { game.stage?.lowercased().contains("semifinal") == true }

    private var bannerText: String? {
        if isFinal { return "Final" }
        if isSemifinal { return "Semifinal" }
        return nil
    }

    private var stageTagText: String? {
        guard bannerText == nil, let stage = game.stage, !stage.isEmpty else { return nil }
        return stage.capitalized
    }

    private var groupTagText: String? {
        game.group ?? game.bracket
    }

    var body: some View {
        VStack(spacing: 0) {
            if let bannerText {
                HStack {
                    Text(bannerText)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(isFinal ? AppTheme.Colors.accentText : .white)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isFinal ? AppTheme.Colors.accent : GameCardPalette.semifinalBanner)
            }

            VStack(spacing: 14) {
                HStack(spacing: AppTheme.Spacing.large) {
                    TeamSection(
                        teamName: game.homeTeam?.name ?? "TBD",
                        isWinner: game.isFinished && game.winner?.id == game.homeTeam?.id,
                        imageURL: game.homeTeam?.fullImageURL
                    )
                    .frame(maxWidth: .infinity)

                    CenterSection(game: game)
                        .frame(width: 130)

                    TeamSection(
                        teamName: game.awayTeam?.name ?? "TBD",
                        isWinner: game.isFinished && game.winner?.id == game.awayTeam?.id,
                        imageURL: game.awayTeam?.fullImageURL
                    )
                    .frame(maxWidth: .infinity)
                }

                if let venue = game.venue {
                    VenueLabel(venue: venue)
                }

                if stageTagText != nil || groupTagText != nil {
                    HStack(spacing: 8) {
                        if let stageTagText {
                            tag(stageTagText, fill: GameCardPalette.stageTagFill, textColor: AppTheme.Colors.secondaryText)
                        }
                        if let groupTagText {
                            tag(groupTagText, fill: GameCardPalette.groupTagFill, textColor: .white)
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(GameCardPalette.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large))
    }

    private func tag(_ text: String, fill: Color, textColor: Color) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(textColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(fill))
    }
}
```

- [ ] **Step 3: Replace `TeamSection`**

Replace the entire existing `struct TeamSection: View { … }` with:

```swift
/// Team logo (winner gets a lime ring) with the name below.
struct TeamSection: View {
    let teamName: String
    let isWinner: Bool
    var imageURL: String? = nil

    var body: some View {
        VStack(spacing: AppTheme.Spacing.small) {
            ZStack {
                logoCircle
                if isWinner {
                    Circle()
                        .stroke(AppTheme.Colors.accent, lineWidth: 2)
                        .frame(width: 62, height: 62)
                }
            }
            Text(teamName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.primaryText)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
    }

    @ViewBuilder
    private var logoCircle: some View {
        if let imageURL, let url = URL(string: imageURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill().frame(width: 54, height: 54).clipShape(Circle())
                default:
                    initialsCircle
                }
            }
        } else {
            initialsCircle
        }
    }

    private var initialsCircle: some View {
        Circle()
            .fill(Color(white: 0.15))
            .frame(width: 54, height: 54)
            .overlay(
                Text(initials)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(AppTheme.Colors.primaryText)
            )
    }

    private var initials: String {
        let words = teamName.split(separator: " ")
        if words.count >= 2 {
            return String(words[0].prefix(1) + words[1].prefix(1)).uppercased()
        } else if let first = words.first {
            return String(first.prefix(3)).uppercased()
        }
        return "TBD"
    }
}
```

- [ ] **Step 4: Replace `CenterSection`**

Replace the entire existing `struct CenterSection: View { … }` with:

```swift
/// Center of the card: score (winner in accent) when finished, else the start time.
struct CenterSection: View {
    let game: Game

    private var homeIsWinner: Bool { game.isFinished && game.winner?.id == game.homeTeam?.id }
    private var awayIsWinner: Bool { game.isFinished && game.winner?.id == game.awayTeam?.id }

    var body: some View {
        if game.isFinished {
            HStack(spacing: 8) {
                Text("\(game.homeScore ?? 0)")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(homeIsWinner ? AppTheme.Colors.accent : AppTheme.Colors.primaryText)
                Text("-")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(Color(white: 0.45))
                Text("\(game.awayScore ?? 0)")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(awayIsWinner ? AppTheme.Colors.accent : AppTheme.Colors.primaryText)
            }
            .fixedSize()
        } else if let gameTime = game.gameTime {
            Text(Self.timeFormatter.string(from: gameTime))
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppTheme.Colors.primaryText)
                .fixedSize()
        } else {
            Text("—")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color(white: 0.45))
        }
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_MX")
        f.timeZone = AppConfig.DateTime.apiTimeZone
        f.dateFormat = "h:mm a"
        return f
    }()
}
```

- [ ] **Step 5: Add a preview for the card variants**

Add above the existing `#Preview { … GamesListView … }` at the file bottom:

```swift
#Preview("Game cards") {
    func sample(stage: String, group: String?, bracket: String?, finished: Bool) -> Game {
        Game(
            id: Int.random(in: 1...99999),
            gameTime: Date(),
            stage: stage,
            bracketId: nil,
            venue: Venue(name: "Polideportivo Central", courtNumber: "1", lat: nil, lng: nil),
            teamStats: [
                TeamStat(id: 1, score: finished ? 48 : nil, result: finished ? "Won" : nil, teamName: "Sonora A", teamLogo: nil),
                TeamStat(id: 2, score: finished ? 43 : nil, result: finished ? "Lost" : nil, teamName: "Sinaloa B", teamLogo: nil)
            ],
            group: group,
            bracket: bracket
        )
    }
    return ScrollView {
        VStack(spacing: 16) {
            GameCard(game: sample(stage: "Final", group: nil, bracket: "Playoffs", finished: true))
            GameCard(game: sample(stage: "Semifinal", group: nil, bracket: "Playoffs", finished: true))
            GameCard(game: sample(stage: "Ronda regular", group: "Grupo 1", bracket: nil, finished: true))
            GameCard(game: sample(stage: "Ronda regular", group: "Grupo 1", bracket: nil, finished: false))
        }
        .padding()
    }
    .background(Color.black)
}
```

> Note: `Game`'s memberwise init omits `isLive`/`period` (they default). Confirm the argument order against `Game.swift` while typing; adjust if the struct differs.

- [ ] **Step 6: Build and verify in Xcode**

Run: **⌘B**, open the **"Game cards"** preview.
Expected: four dark cards — a **Final** with a lime banner + black "Final" text, a **Semifinal** with a blue banner + white text (both with a purple "Playoffs" tag and no gray stage tag), a finished regular game (`48 - 43` with 48 in lime, green "Polideportivo Central", gray "Ronda Regular" + purple "Grupo 1"), and an upcoming regular game showing a time instead of a score.

- [ ] **Step 7: Commit** (only if authorized)

```bash
git add Brackets/GamesListView.swift
git commit -m "Redesign game card with banner, location, and tags"
```

---

### Task 3: Group/bracket filter carousel

**Files:**
- Modify: `Brackets/GamesListView.swift`

**Interfaces:**
- Consumes: `AppTheme` tokens.
- Produces: `struct GameGroupChip` (with `Kind`, `name`, `id`); `struct GroupFilterCarousel(chips: [GameGroupChip], selected: Binding<GameGroupChip?>)`; three private `PreferenceKey`s. Used by `GamesListView` in Task 4.

- [ ] **Step 1: Add the chip model and preference keys**

Add near the top of `GamesListView.swift` (after `GameCardPalette` from Task 2):

```swift
/// A single filter chip — either a group ("Grupo 1") or a playoff bracket ("Playoffs").
struct GameGroupChip: Identifiable, Equatable {
    enum Kind { case group, bracket }
    let name: String
    let kind: Kind
    var id: String { "\(kind == .group ? "g" : "b")-\(name)" }
}

private struct CarouselContentWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

private struct CarouselOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

private struct CarouselContainerWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}
```

- [ ] **Step 2: Add the carousel view**

Add after the preference keys:

```swift
/// Horizontally scrollable chip row with overflow chevron buttons.
struct GroupFilterCarousel: View {
    let chips: [GameGroupChip]
    @Binding var selected: GameGroupChip?

    @State private var contentWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var offsetX: CGFloat = 0   // content leading edge X; 0 at start, negative when scrolled

    private let space = "groupCarousel"

    private var canScrollLeft: Bool { offsetX < -4 }
    private var canScrollRight: Bool {
        contentWidth > containerWidth + 1 && offsetX > (containerWidth - contentWidth) + 4
    }

    var body: some View {
        ScrollViewReader { proxy in
            ZStack {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppTheme.Spacing.small) {
                        ForEach(chips) { chip in
                            chipButton(chip).id(chip.id)
                        }
                    }
                    .padding(.horizontal, AppTheme.Layout.screenPadding)
                    .background(
                        GeometryReader { geo in
                            Color.clear
                                .preference(key: CarouselContentWidthKey.self, value: geo.size.width)
                                .preference(key: CarouselOffsetKey.self, value: geo.frame(in: .named(space)).minX)
                        }
                    )
                }
                .coordinateSpace(name: space)
                .onPreferenceChange(CarouselContentWidthKey.self) { contentWidth = $0 }
                .onPreferenceChange(CarouselOffsetKey.self) { offsetX = $0 }

                HStack {
                    if canScrollLeft { arrow("chevron.left") { scroll(-1, proxy) } }
                    Spacer()
                    if canScrollRight { arrow("chevron.right") { scroll(1, proxy) } }
                }
                .padding(.horizontal, 4)
            }
            .background(
                GeometryReader { geo in
                    Color.clear.preference(key: CarouselContainerWidthKey.self, value: geo.size.width)
                }
            )
            .onPreferenceChange(CarouselContainerWidthKey.self) { containerWidth = $0 }
        }
        .frame(height: 44)
    }

    private func scroll(_ direction: Int, _ proxy: ScrollViewProxy) {
        guard !chips.isEmpty, contentWidth > 0, containerWidth > 0 else { return }
        let avg = contentWidth / CGFloat(chips.count)
        let current = max(0, Int((-offsetX / avg).rounded()))
        let page = max(1, Int((containerWidth / avg).rounded(.down)))
        let target = min(max(0, current + direction * page), chips.count - 1)
        withAnimation(.easeInOut(duration: 0.25)) {
            proxy.scrollTo(chips[target].id, anchor: direction > 0 ? .trailing : .leading)
        }
    }

    private func chipButton(_ chip: GameGroupChip) -> some View {
        let isSelected = selected == chip
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selected = chip }
        } label: {
            Text(chip.name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.primaryText)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Capsule().fill(isSelected ? Color.clear : Color(white: 0.15)))
                .overlay(Capsule().stroke(AppTheme.Colors.accent, lineWidth: isSelected ? 1.5 : 0))
        }
        .buttonStyle(.plain)
    }

    private func arrow(_ system: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Color(white: 0.15)))
                .shadow(color: .black.opacity(0.4), radius: 4)
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 3: Add a preview**

Add above the `#Preview("Game cards")` block:

```swift
#Preview("Group carousel") {
    struct Wrap: View {
        @State var sel: GameGroupChip? = GameGroupChip(name: "Grupo 1", kind: .group)
        var chips: [GameGroupChip] {
            (1...13).map { GameGroupChip(name: "Grupo \($0)", kind: .group) }
            + ["Playoffs", "Playoffs 2", "Playoffs 3"].map { GameGroupChip(name: $0, kind: .bracket) }
        }
        var body: some View {
            GroupFilterCarousel(chips: chips, selected: $sel)
        }
    }
    return ZStack { Color.black.ignoresSafeArea(); Wrap() }
}
```

- [ ] **Step 4: Build and verify in Xcode**

Run: **⌘B**, open the **"Group carousel"** preview.
Expected: a row of chips with **"Grupo 1"** selected (lime outline, no fill) and the rest gray-filled; a circular **chevron.right** button on the right; tapping it scrolls the row and a **chevron.left** appears; the row includes the bracket chips after `Grupo 13`.

- [ ] **Step 5: Commit** (only if authorized)

```bash
git add Brackets/GamesListView.swift
git commit -m "Add group/bracket filter carousel with overflow arrows"
```

---

### Task 4: Rewire GamesListView — filters, chips, date header

**Files:**
- Modify: `Brackets/GamesListView.swift`

**Interfaces:**
- Consumes: `GameGroupChip`, `GroupFilterCarousel` (Task 3); redesigned `GameCard` (Task 2); `Game.group`/`Game.bracket`, `GamesResponse.brackets`, `BracketInfo` (Task 1).
- Produces: updated `GamesListView` behavior. `GameFilter` loses `.all`.

- [ ] **Step 1: Remove the `.all` case from `GameFilter`**

Change the enum to:

```swift
enum GameFilter: String, CaseIterable {
    case live = "En Vivo"
    case upcoming = "Próximos"
    case completed = "Resultados"
}
```

- [ ] **Step 2: Update `GamesListView` state and `availableFilters`**

Change the default filter and add chip state. Replace:

```swift
    @State private var selectedFilter: GameFilter = .all
```

with:

```swift
    @State private var selectedFilter: GameFilter = .upcoming
    @State private var selectedChip: GameGroupChip?
    @State private var didInitChip = false
```

Replace `availableFilters` with:

```swift
    private var availableFilters: [GameFilter] {
        var filters: [GameFilter] = []
        if hasLiveGames { filters.append(.live) }
        filters.append(contentsOf: [.upcoming, .completed])
        return filters
    }
```

- [ ] **Step 3: Add chip building + tab/chip matching helpers**

Add these methods inside `GamesListView` (e.g. after `availableFilters`):

```swift
    private var chips: [GameGroupChip] {
        guard let response = gamesResponse else { return [] }
        let all = response.allGames

        let groupChips = Set(all.compactMap { $0.group })
            .sorted { lhs, rhs in
                switch (trailingInt(lhs), trailingInt(rhs)) {
                case let (l?, r?) where l != r: return l < r
                default: return lhs < rhs
                }
            }
            .map { GameGroupChip(name: $0, kind: .group) }

        let order = Dictionary(uniqueKeysWithValues:
            (response.brackets ?? []).compactMap { info in info.position.map { (info.name, $0) } })
        let bracketChips = Set(all.compactMap { $0.bracket })
            .sorted { lhs, rhs in
                switch (order[lhs], order[rhs]) {
                case let (l?, r?) where l != r: return l < r
                case (nil, _?): return false
                case (_?, nil): return true
                default: return lhs < rhs
                }
            }
            .map { GameGroupChip(name: $0, kind: .bracket) }

        return groupChips + bracketChips
    }

    private func trailingInt(_ s: String) -> Int? {
        if let last = s.split(separator: " ").last, let n = Int(last) { return n }
        return nil
    }

    private func matchesTab(_ game: Game) -> Bool {
        switch selectedFilter {
        case .live: return game.isLive
        case .upcoming: return !game.isFinished && !game.isLive
        case .completed: return game.isFinished && !game.isLive
        }
    }

    private func matches(_ game: Game, _ chip: GameGroupChip) -> Bool {
        switch chip.kind {
        case .group: return game.group == chip.name
        case .bracket: return game.bracket == chip.name
        }
    }

    private func ensureValidChip() {
        let list = chips
        guard !list.isEmpty else { selectedChip = nil; return }
        let hasGames: (GameGroupChip) -> Bool = { chip in
            self.gamesResponse?.allGames.contains { self.matchesTab($0) && self.matches($0, chip) } ?? false
        }
        if let sel = selectedChip, list.contains(sel), hasGames(sel) { return }
        selectedChip = list.first(where: hasGames) ?? list.first
    }
```

- [ ] **Step 4: Replace `filteredGames`**

Replace the entire `filteredGames` computed property with:

```swift
    var filteredGames: [GamesResponse.DateGroup] {
        guard let gamesResponse = gamesResponse, let chip = selectedChip else { return [] }
        let groups = gamesResponse.games.map { dateGroup in
            GamesResponse.DateGroup(
                date: dateGroup.date,
                games: dateGroup.games.filter { matchesTab($0) && matches($0, chip) }
            )
        }.filter { !$0.games.isEmpty }
        let ascending = selectedFilter != .completed
        return groups.sorted { ascending ? $0.date < $1.date : $0.date > $1.date }
    }
```

- [ ] **Step 5: Insert the carousel and update chip lifecycle in `body`**

In `body`, replace the filter block:

```swift
                    // Filter Buttons
                    GameFilterView(selectedFilter: $selectedFilter, filters: availableFilters)
                        .padding(.horizontal, AppTheme.Layout.screenPadding)
                        .padding(.top, AppTheme.Spacing.medium)
                        .padding(.bottom, AppTheme.Spacing.large)
```

with:

```swift
                    // Top filter (Próximos / Resultados / En Vivo)
                    GameFilterView(selectedFilter: $selectedFilter, filters: availableFilters)
                        .padding(.horizontal, AppTheme.Layout.screenPadding)
                        .padding(.top, AppTheme.Spacing.medium)
                        .padding(.bottom, AppTheme.Spacing.small)

                    // Group / bracket carousel
                    GroupFilterCarousel(chips: chips, selected: $selectedChip)
                        .padding(.bottom, AppTheme.Spacing.medium)
                        .onChange(of: selectedFilter) { ensureValidChip() }
```

- [ ] **Step 6: Add the date-header count badge and new date format**

In `body`, replace the date-header `HStack` (the calendar icon + `Text(formatDateHeader(...))`) with:

```swift
                                            // Date Header with calendar icon + count
                                            HStack(spacing: 8) {
                                                Image(systemName: "calendar")
                                                    .font(.system(size: 14, weight: .semibold))
                                                    .foregroundStyle(AppTheme.Colors.accent)

                                                Text(formatDateHeader(dateGroup.date))
                                                    .font(.system(size: 16, weight: .bold))
                                                    .foregroundStyle(AppTheme.Colors.primaryText)

                                                Text(dateGroup.games.count == 1 ? "1 Juego" : "\(dateGroup.games.count) Juegos")
                                                    .font(.system(size: 12, weight: .semibold))
                                                    .foregroundStyle(AppTheme.Colors.secondaryText)
                                                    .padding(.horizontal, 10)
                                                    .padding(.vertical, 4)
                                                    .background(Capsule().fill(Color(white: 0.2)))
                                            }
                                            .padding(.horizontal, AppTheme.Layout.screenPadding)
```

Replace the entire `formatDateHeader(_:)` method with:

```swift
    private func formatDateHeader(_ dateString: String) -> String {
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        parser.timeZone = AppConfig.DateTime.apiTimeZone
        guard let date = parser.date(from: dateString) else { return dateString }

        let f = DateFormatter()
        f.locale = Locale(identifier: "es_MX")
        f.timeZone = AppConfig.DateTime.apiTimeZone

        f.dateFormat = "EEEE"
        let weekday = f.string(from: date).capitalized
        f.dateFormat = "MMMM"
        let month = f.string(from: date).capitalized
        f.dateFormat = "d"
        let day = f.string(from: date)
        return "\(weekday), \(day) de \(month)"
    }
```

- [ ] **Step 7: Initialize the chip on load and fix the live-refresh `.all` references**

In `loadGames()`, after `gamesResponse = try await …`, initialize the chip once:

```swift
        do {
            gamesResponse = try await APIService.shared.fetchGamesResponse(for: tournament.id)
            if !didInitChip {
                ensureValidChip()
                didInitChip = true
            }
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
```

In `startLiveRefreshIfNeeded()`, change:

```swift
        if selectedFilter == .all {
            selectedFilter = .live
        }
```

to:

```swift
        if selectedFilter == .upcoming {
            selectedFilter = .live
        }
```

In `refreshLiveGames()`, change the branch `if selectedFilter == .live { selectedFilter = .all }` to:

```swift
                        if selectedFilter == .live {
                            selectedFilter = .upcoming
                        }
```

- [ ] **Step 8: Build and verify in Xcode**

Run: **⌘B**, then run the app on a tournament (or the main `GamesListView` `#Preview`).
Expected: builds with no remaining `.all` references. The top row shows **Próximos / Resultados** (+ **En Vivo** only with live games); a group carousel sits below with one chip selected and arrows when it overflows; date headers read **"Jueves, 18 de Junio"** with an **"N Juegos"** badge; cards match the new design; switching the top tab keeps a valid chip selected; tapping a chip filters the list; game rows still navigate to their detail screens.

- [ ] **Step 9: Commit** (only if authorized)

```bash
git add Brackets/GamesListView.swift
git commit -m "Wire group carousel, top-filter, and date header into games list"
```

---

## Self-Review

**Spec coverage:**
- Model `group`/`bracket` + `BracketInfo`/`brackets` → Task 1. ✔
- Drop `.all`, keep conditional En Vivo, default `.upcoming` → Task 4 Steps 1–2, 7. ✔
- Chip list (natural-sorted groups + position-ordered brackets), always-one-selected, auto-reselect → Task 4 Steps 3, 7 + Task 3. ✔
- Carousel with overflow arrows → Task 3. ✔
- Chip styling (accent outline selected / gray unselected) → Task 3 Step 2. ✔
- Date header format + "N Juegos" badge + sort → Task 4 Steps 4, 6. ✔
- Card unified + Final/Semifinal banner + winner ring + score/time + location + tags (stage suppressed under banner) → Task 2. ✔
- Reuse `VenueLabel` → Task 2 Step 2. ✔
- `LiveGameCard`/navigation unchanged → not modified. ✔

**Placeholder scan:** No TBD/TODO; all steps carry complete code. The preview init-order note (Task 2 Step 5) is a verification aid.

**Type consistency:** `GameGroupChip(name:kind:)`, `chips`, `selectedChip`, `matchesTab`, `matches(_: _:)`, `ensureValidChip`, `trailingInt`, `GameCardPalette`, `TeamSection(teamName:isWinner:imageURL:)`, `CenterSection(game:)`, `GroupFilterCarousel(chips:selected:)` are consistent across Tasks 1–4. `GameFilter` has no `.all` after Task 4 and every `switch` over it (`matchesTab`) is exhaustive with `.live`/`.upcoming`/`.completed`.
