# Top Stats Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restyle the Top Stats view (per-category card with podium + full ranked list + "Ver listado completo" footer, team under name everywhere) and add a filtered full-leaderboard screen.

**Architecture:** Add `rank` to `PlayerStatEntry` + a `TopStatDetail` response; add `fetchTopStatDetail`; restyle each carousel page in `StatsLeadersView` into a single card whose footer pushes a new `TopStatDetailView` (name + team filters over the full list from `top_stat.json?stat=<key>`).

**Tech Stack:** SwiftUI (iOS 17+), pure Swift, `AppTheme` tokens.

**Branch:** independent of the games/bracket work — branch off `main`.

## Global Constraints

- **No terminal build/test tooling** — verify in **Xcode**: build **⌘B** + inspect the Stats tab / `#Preview`. No XCTest step.
- Dark mode only; UI text Spanish; locale `es_MX`.
- Stat key for `?stat=` = `category.stats.first?.statName` (machine key, e.g. `"points"`).
- Score formatting: main screen `tournament.usesAverage ? "%.1f" : "%.0f"`; full-list screen uses the response `average` flag.
- Podium: #1 green ring + green crown; green circular rank badges; name bold, **team gray under name**, **score white bold** (not green). List rows: rank + circular avatar + **name/team** + white bold score. Footer "Ver listado completo" accent green.
- Player photo URL: `picture.hasPrefix("http") ? picture : "\(APIConfig.baseURL)/\(picture)"`; initials fallback.
- Podium players and list rows push `PlayerDetailView(stat:tournamentId:)`; footer pushes `TopStatDetailView`.
- Do **not** run `git commit` unless explicitly authorized; commit steps are for completeness.
- SourceKit cross-file "cannot find X in scope" errors are false positives; ignore them.

---

## File Structure

- **Modify `Brackets/Stats.swift`:** `PlayerStatEntry.rank`; `TopStatDetail`.
- **Modify `Brackets/APIService.swift`:** `fetchTopStatDetail(for:stat:)`.
- **Create `Brackets/TopStatDetailView.swift`:** full list + Buscar/Equipo filters.
- **Modify `Brackets/StatsLeadersView.swift`:** restyle `categoryPage`/`podiumPlayer`/rows into one card; footer link; circular row avatar.

---

### Task 1: Models — `PlayerStatEntry.rank` + `TopStatDetail`

**Files:**
- Modify: `Brackets/Stats.swift`

**Interfaces:**
- Produces: `PlayerStatEntry.rank: Int?`; `struct TopStatDetail { stat, statName, statShortName, average: Bool, players: [PlayerStatEntry] }`.

- [ ] **Step 1: Add `rank` to `PlayerStatEntry`**

In `struct PlayerStatEntry`, add the stored property after `let player: Player`:

```swift
    let rank: Int?
```

Add `case rank` to its `CodingKeys`:

```swift
    enum CodingKeys: String, CodingKey {
        case statShortName = "stat_short_name"
        case statName = "stat_name"
        case score
        case teamName = "team_name"
        case playerSeasonId = "player_season_id"
        case player
        case rank
    }
```

In its `init(from:)`, add after `player = try container.decode(Player.self, forKey: .player)`:

```swift
        rank = try container.decodeIfPresent(Int.self, forKey: .rank)
```

- [ ] **Step 2: Add the `TopStatDetail` response type**

Add at the bottom of `Stats.swift`:

```swift
// MARK: - Full-list (single stat) response

struct TopStatDetail: Codable, Sendable {
    let stat: String
    let statName: String
    let statShortName: String
    let average: Bool
    let players: [PlayerStatEntry]

    enum CodingKeys: String, CodingKey {
        case stat
        case statName = "stat_name"
        case statShortName = "stat_short_name"
        case average
        case players
    }
}
```

- [ ] **Step 3: Build**

Run: **⌘B**. Expected: builds. `PlayerStatEntry` still decodes the main `top_stats` (rank → nil) and now also the full-list entries (rank populated). No behavior change yet.

- [ ] **Step 4: Commit** (only if authorized)

```bash
git add Brackets/Stats.swift
git commit -m "Add rank to PlayerStatEntry and TopStatDetail response"
```

---

### Task 2: API — `fetchTopStatDetail`

**Files:**
- Modify: `Brackets/APIService.swift`

**Interfaces:**
- Consumes: `TopStatDetail` (Task 1).
- Produces: `func fetchTopStatDetail(for tournamentId: Int, stat: String) async throws -> TopStatDetail`.

- [ ] **Step 1: Add the fetch method**

Add inside `APIService`, right after `fetchTopStats(for:)`:

```swift
    func fetchTopStatDetail(for tournamentId: Int, stat: String) async throws -> TopStatDetail {
        let encodedStat = stat.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? stat
        guard let url = URL(string: "\(APIConfig.apiURL)/tournaments/\(tournamentId)/top_stat.json?stat=\(encodedStat)") else {
            throw APIError.invalidURL
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                print("❌ Top Stat Detail: Bad HTTP status")
                throw APIError.invalidResponse
            }

            do {
                let detail = try JSONDecoder().decode(TopStatDetail.self, from: data)
                print("✅ Decoded top stat detail — \(detail.players.count) players")
                return detail
            } catch let decodingError {
                print("❌ Top Stat Detail Decoding Error: \(decodingError)")
                throw APIError.decodingError(decodingError)
            }
        } catch let error as APIError {
            throw error
        } catch {
            print("❌ Top Stat Detail Network Error: \(error)")
            throw APIError.networkError(error)
        }
    }
```

- [ ] **Step 2: Build**

Run: **⌘B**. Expected: builds. Method compiles; unused until Task 3.

- [ ] **Step 3: Commit** (only if authorized)

```bash
git add Brackets/APIService.swift
git commit -m "Add fetchTopStatDetail for the full stat leaderboard"
```

---

### Task 3: Full-list screen with filters (`TopStatDetailView`)

**Files:**
- Create: `Brackets/TopStatDetailView.swift`

**Interfaces:**
- Consumes: `fetchTopStatDetail` (Task 2), `PlayerStatEntry`/`Player`, `PlayerDetailView(stat:tournamentId:)`, `Tournament`, `AppTheme`, `APIConfig`.
- Produces: `struct TopStatDetailView` taking `tournament: Tournament`, `stat: String`, `categoryName: String`.

- [ ] **Step 1: Create `Brackets/TopStatDetailView.swift`**

```swift
//
//  TopStatDetailView.swift
//  Brackets
//

import SwiftUI

struct TopStatDetailView: View {
    let tournament: Tournament
    let stat: String
    let categoryName: String

    @State private var detail: TopStatDetail?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var search = ""
    @State private var selectedTeam = "Todos"

    private var players: [PlayerStatEntry] { detail?.players ?? [] }

    private var teams: [String] {
        ["Todos"] + Set(players.map { $0.teamName }).sorted()
    }

    private var filteredPlayers: [PlayerStatEntry] {
        players.filter { entry in
            let nameOK = search.isEmpty || entry.player.fullName.localizedCaseInsensitiveContains(search)
            let teamOK = selectedTeam == "Todos" || entry.teamName == selectedTeam
            return nameOK && teamOK
        }
    }

    private func formatScore(_ score: Double) -> String {
        (detail?.average ?? tournament.usesAverage) ? String(format: "%.1f", score) : String(format: "%.0f", score)
    }

    var body: some View {
        Group {
            if isLoading {
                AppTheme.LoadingView(message: "Loading stats...")
            } else if let errorMessage {
                AppTheme.ErrorView(message: errorMessage) {
                    Task { await load() }
                }
            } else {
                VStack(spacing: 0) {
                    filterCard
                        .padding(.horizontal, AppTheme.Layout.screenPadding)
                        .padding(.top, AppTheme.Spacing.medium)
                        .padding(.bottom, AppTheme.Spacing.small)

                    if filteredPlayers.isEmpty {
                        AppTheme.EmptyStateView(icon: "person.slash", message: "No hay jugadores.")
                            .frame(maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: AppTheme.Spacing.small) {
                                ForEach(filteredPlayers) { entry in
                                    NavigationLink {
                                        PlayerDetailView(stat: entry, tournamentId: tournament.id)
                                    } label: {
                                        row(entry)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, AppTheme.Layout.screenPadding)
                            .padding(.vertical, AppTheme.Spacing.medium)
                        }
                    }
                }
            }
        }
        .navigationTitle(categoryName)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    // MARK: - Filter card

    private var filterCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Buscar")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.primaryText)
                TextField("Nombre", text: $search)
                    .font(.system(size: 15))
                    .foregroundStyle(AppTheme.Colors.primaryText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large)
                            .fill(Color(white: 0.12))
                            .stroke(Color(white: 0.3), lineWidth: 1)
                    )
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Equipo")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.primaryText)
                Menu {
                    ForEach(teams, id: \.self) { team in
                        Button(team) { selectedTeam = team }
                    }
                } label: {
                    HStack {
                        Text(selectedTeam)
                            .font(.system(size: 15))
                            .foregroundStyle(AppTheme.Colors.primaryText)
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large)
                            .fill(Color(white: 0.12))
                            .stroke(Color(white: 0.3), lineWidth: 1)
                    )
                }
            }
        }
        .padding(AppTheme.Layout.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large)
                .fill(Color(white: 0.1))
        )
    }

    // MARK: - Row

    private func row(_ entry: PlayerStatEntry) -> some View {
        HStack(spacing: AppTheme.Spacing.medium) {
            Text("\(entry.rank ?? 0)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .frame(width: 28, alignment: .center)

            avatar(entry.player, size: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.player.fullName)
                    .font(AppTheme.Typography.bodyBold)
                    .foregroundStyle(AppTheme.Colors.primaryText)
                    .lineLimit(1)
                Text(entry.teamName)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .lineLimit(1)
            }

            Spacer()

            Text(formatScore(entry.score))
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AppTheme.Colors.primaryText)
        }
        .cardStyle()
    }

    // MARK: - Avatar

    @ViewBuilder
    private func avatar(_ player: Player, size: CGFloat) -> some View {
        if let picture = player.picture,
           let url = URL(string: picture.hasPrefix("http") ? picture : "\(APIConfig.baseURL)/\(picture)") {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    avatarInitials(player)
                }
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
        } else {
            avatarInitials(player)
                .frame(width: size, height: size)
        }
    }

    private func avatarInitials(_ player: Player) -> some View {
        Circle()
            .fill(Color(white: 0.2))
            .overlay(
                Text("\(player.firstName.prefix(1))\(player.lastName.prefix(1))".uppercased())
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            )
    }

    // MARK: - Data

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            detail = try await APIService.shared.fetchTopStatDetail(for: tournament.id, stat: stat)
            isLoading = false
        } catch {
            errorMessage = "Failed to load stats"
            isLoading = false
        }
    }
}

#Preview {
    NavigationStack {
        TopStatDetailView(
            tournament: Tournament(id: 1, name: "Femenil 2011", gender: .female, teamCount: 8, image: nil),
            stat: "points",
            categoryName: "Puntos"
        )
    }
}
```

> Note: confirm `Tournament(...)` init labels and the `Gender` case (`.female`/`.male`) against `Brackets/Tournament.swift` when typing the preview; adjust if they differ. `PlayerDetailView(stat:tournamentId:)` and `.cardStyle()` already exist (used in `StatsLeadersView`).

- [ ] **Step 2: Build and verify in Xcode**

Run: **⌘B**, open the "TopStatDetailView" `#Preview` (shows the loading state / filter card without network).
Expected: builds. The filter card renders "Buscar" + input and "Equipo" + dropdown. (Full behavior verified on device in Task 4 once the link is wired.)

- [ ] **Step 3: Commit** (only if authorized)

```bash
git add Brackets/TopStatDetailView.swift
git commit -m "Add TopStatDetailView: full stat leaderboard with name/team filters"
```

---

### Task 4: Restyle the main stats card + footer link (`StatsLeadersView`)

**Files:**
- Modify: `Brackets/StatsLeadersView.swift`

**Interfaces:**
- Consumes: `TopStatDetailView` (Task 3); existing `podiumView`/`podiumPlayer`/`PlayerDetailView`.
- Produces: single-card `categoryPage`, white podium scores, flat list rows with team + circular avatar, "Ver listado completo" footer.

- [ ] **Step 1: Replace `categoryPage` with the single-card layout**

Replace the entire `categoryPage(_:)` method with:

```swift
    private func categoryPage(_ category: StatCategory) -> some View {
        let top3 = Array(category.stats.prefix(3))
        let rest = Array(category.stats.dropFirst(3))
        let statKey = category.stats.first?.statName ?? ""

        return ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                // Title
                Text(category.name ?? "")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppTheme.Colors.primaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppTheme.Spacing.medium)

                Divider().overlay(Color(white: 0.2))

                // Podium (top 3) or fallback rows
                if top3.count >= 3 {
                    podiumView(top3: top3)
                        .padding(.horizontal, AppTheme.Layout.cardPadding)
                        .padding(.top, AppTheme.Spacing.large)
                        .padding(.bottom, AppTheme.Spacing.medium)
                } else {
                    ForEach(Array(top3.enumerated()), id: \.element.id) { index, stat in
                        statRowLink(stat: stat, rank: index + 1)
                        if index < top3.count - 1 {
                            Divider().overlay(Color(white: 0.15)).padding(.horizontal, AppTheme.Layout.cardPadding)
                        }
                    }
                }

                // Rest of the players
                ForEach(Array(rest.enumerated()), id: \.element.id) { index, stat in
                    Divider().overlay(Color(white: 0.15)).padding(.horizontal, AppTheme.Layout.cardPadding)
                    statRowLink(stat: stat, rank: index + 4)
                }

                // Footer link → full list
                if !category.stats.isEmpty {
                    Divider().overlay(Color(white: 0.15)).padding(.horizontal, AppTheme.Layout.cardPadding)
                    NavigationLink {
                        TopStatDetailView(tournament: tournament, stat: statKey, categoryName: category.name ?? "")
                    } label: {
                        Text("Ver listado completo")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppTheme.Colors.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppTheme.Spacing.medium)
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large)
                    .fill(Color(white: 0.1))
            )
            .padding(.horizontal, AppTheme.Layout.screenPadding)
            .padding(.bottom, AppTheme.Spacing.huge)
        }
    }

    private func statRowLink(stat: PlayerStatEntry, rank: Int) -> some View {
        NavigationLink {
            PlayerDetailView(stat: stat, tournamentId: tournament.id)
        } label: {
            statListRow(stat: stat, rank: rank)
        }
        .buttonStyle(.plain)
    }

    private func statListRow(stat: PlayerStatEntry, rank: Int) -> some View {
        HStack(spacing: AppTheme.Spacing.medium) {
            Text("\(rank)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .frame(width: 24, alignment: .center)

            circularAvatar(stat.player, size: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(stat.player.fullName)
                    .font(AppTheme.Typography.bodyBold)
                    .foregroundStyle(AppTheme.Colors.primaryText)
                    .lineLimit(1)
                Text(stat.teamName)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .lineLimit(1)
            }

            Spacer()

            Text(formatScore(stat.score))
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppTheme.Colors.primaryText)
        }
        .padding(.horizontal, AppTheme.Layout.cardPadding)
        .padding(.vertical, AppTheme.Spacing.medium)
    }

    private func circularAvatar(_ player: Player, size: CGFloat) -> some View {
        Group {
            if let picture = player.picture,
               let url = URL(string: picture.hasPrefix("http") ? picture : "\(APIConfig.baseURL)/\(picture)") {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        avatarPlaceholder(player)
                    }
                }
            } else {
                avatarPlaceholder(player)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
```

- [ ] **Step 2: Make the podium score white (drop the green glow)**

In `podiumPlayer(...)`, replace the score `Text`:

```swift
            // Score
            Text(formatScore(stat.score))
                .font(.system(size: 24, weight: .heavy))
                .foregroundStyle(AppTheme.Colors.primaryText)
```

(Remove the `.foregroundStyle(AppTheme.Colors.accent)` and both `.shadow(...)` lines that were on the score.)

- [ ] **Step 3: Remove the now-unused old row helpers**

Delete `playerRow(stat:rank:)`, `rankIndicator(rank:)`, and `playerAvatar(_:)` (replaced by `statListRow`/`circularAvatar`). Keep `avatarPlaceholder(_:)` and `playerInitials(_:)` (still used by `circularAvatar`/podium). Confirm via grep that `playerRow`/`rankIndicator`/`playerAvatar` have no remaining references.

- [ ] **Step 4: Build and verify in Xcode**

Run: **⌘B**, open the Stats tab on a tournament.
Expected: builds. Each category is one card: centered title with a divider, the podium (crown/green ring/green rank badges, name, team under name, **white** score), then a flat list of the remaining players (rank + circular avatar + name/team + white score, divider-separated), then a green **"Ver listado completo"** footer. Tapping a podium player or a row opens `PlayerDetailView`; tapping the footer opens `TopStatDetailView`, where the Buscar/Equipo filters narrow the list live. Swiping between categories + page dots still works.

- [ ] **Step 5: Commit** (only if authorized)

```bash
git add Brackets/StatsLeadersView.swift
git commit -m "Restyle top-stats card: podium + full list + Ver listado completo link"
```

---

## Self-Review

**Spec coverage:**
- `PlayerStatEntry.rank` + `TopStatDetail` → Task 1. ✔
- `fetchTopStatDetail` (stat param, URL-encoded) → Task 2. ✔
- Restyled single card: title + podium + list + footer; team under name in podium & rows; white podium score; show-all rows; carousel preserved → Task 4. ✔
- Footer → `TopStatDetailView` with `stat = category.stats.first?.statName` → Task 4 Step 1. ✔
- Full-list screen with Buscar (live) + Equipo (Todos + sorted teams) filters, rows keep API `rank`, score uses `average` → Task 3. ✔
- Podium players + rows push `PlayerDetailView` → Tasks 3–4. ✔

**Placeholder scan:** No TBD/TODO; every step carries complete code.

**Type consistency:** `PlayerStatEntry.rank`, `TopStatDetail(players:average:…)`, `fetchTopStatDetail(for:stat:)`, `TopStatDetailView(tournament:stat:categoryName:)`, `PlayerDetailView(stat:tournamentId:)`, `formatScore`, `circularAvatar`/`avatar` are consistent across tasks. Task 4 removes `playerRow`/`rankIndicator`/`playerAvatar` and adds `statListRow`/`statRowLink`/`circularAvatar`; `avatarPlaceholder`/`playerInitials`/`podiumView`/`podiumPlayer` remain.
