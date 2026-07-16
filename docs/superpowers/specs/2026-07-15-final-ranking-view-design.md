# "Ranking Final" Button + Final Ranking View

**Date:** 2026-07-15
**Status:** Approved design, ready for implementation plan

## Summary

Add a "Ranking Final" button pinned at the bottom of the Standings screen (above
the floating tab bar). Tapping it opens a full-screen modal listing every team's
final placement across brackets, from a new `ranking.json` endpoint. The modal
closes via a ✕ in the top-right, returning to Standings. No export button.

## Endpoint

`GET {apiURL}/tournaments/{id}/ranking.json` (same base as all other endpoints;
`apiURL` = `{baseURL}/api`). Verified live shape (from
`https://demo.getbrackets.app/api/tournaments/45/ranking.json`):

```json
{
  "tournament_id": 45,
  "tournament_name": "Femenil 2008-09",
  "available": true,
  "ranking": [
    { "place": 1, "team_id": 417, "team_season_id": 890, "team_name": "Gladiadores Valle", "team_logo": null, "bracket_name": "Gold", "stage_label": "Campeón" },
    { "place": 2, "team_id": 436, "team_season_id": 909, "team_name": "Pingüinos Sierra", "team_logo": null, "bracket_name": "Gold", "stage_label": "Subcampeón" },
    { "place": 3, "team_id": 453, "team_season_id": 926, "team_name": "Cometas Azteca", "team_logo": null, "bracket_name": "Gold", "stage_label": "3er Lugar" }
  ]
}
```

Facts confirmed from the live payload (64 entries):
- `ranking` is a flat list already ordered by `place` (Gold 1–8, Silver 9–24,
  Bronze 25+…). No client-side grouping or sorting needed.
- The "RESULTADO" column maps to **`stage_label`** ("Campeón", "Subcampeón",
  "3er Lugar", "4to Lugar", "Cuartos de Final", "Octavos de Final"). There is a
  `result_label` field elsewhere in the app but the ranking payload has no such
  key — do not use it.
- `team_logo` is `null` for all demo entries; real data may carry a path.
- `bracket_name` can be `null`.

## Decisions

| Decision | Choice |
|----------|--------|
| Button visibility | Fetch `ranking.json`; show the button only when `available == true` **and** `ranking` is non-empty. |
| Avoid double fetch | The availability fetch loads the full ranking; hand that same `RankingResponse` to the modal — the modal does not refetch and needs no loading state. |
| Row layout | Table columns: `#`, EQUIPO (logo + name), BRACKET, RESULTADO. |
| Presentation | `.fullScreenCover`; ✕ top-right dismisses back to Standings. |
| Placement | Inside `StandingsView`, pinned via `.safeAreaInset(edge: .bottom)`. |
| Export button | Omitted. |

## Approach

- Reuse the app's conventions: `Codable`/`Sendable` models with explicit
  snake_case `CodingKeys` and a tolerant `init(from:)`; a `fullImageURL` computed
  property mirroring `PodiumEntry`; `AsyncImage` with an initials-circle fallback;
  `StandingsSurface`/`AppTheme` tokens for the header band and row striping.
- New views live in one new file `RankingView.swift`. The project uses Xcode
  file-system-synchronized groups (`objectVersion 77`,
  `PBXFileSystemSynchronizedRootGroup`), so a new `.swift` file under `Brackets/`
  compiles automatically — **no `project.pbxproj` edit required**.

## Changes

### 1. Data & API — `APIService.swift`

Add models (near the other standings response models) and a fetch method.

```swift
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

Fetch method (mirrors `fetchStandings`):

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

### 2. Ranking modal — `RankingView.swift` (new file)

`RankingView(response: RankingResponse)`:
- Root: `ZStack { AppTheme.Colors.background.ignoresSafeArea(); VStack(spacing: 0) { header; columnHeader; list } }`, dark-mode styling.
- **Header:** title `"\(response.tournamentName) — Ranking Final"` (bold, ~22pt,
  left) and a trailing ✕ button (`Image(systemName: "xmark")` in a circular
  translucent background, matching the container's back button style) calling
  `@Environment(\.dismiss)`.
- **Column header row:** `#`, `EQUIPO`, `BRACKET`, `RESULTADO`, styled with
  `StandingsSurface.header` background and secondary-text caption font.
- **List:** `ScrollView` + `LazyVStack(spacing: 0)` over `response.ranking`,
  rendering `RankingRow(entry:index:)`. Alternating row background
  (`index.isMultiple(of: 2)`) using two subtle surfaces.
- Fixed column widths (constants local to the file):
  - place: 28 (leading, secondary text, bold)
  - logo: 28 circle (`AsyncImage` → success image; else initials circle from
    `String(teamName.prefix(2)).uppercased()` on `Color(white: 0.18)`)
  - team name: flexible (`frame(maxWidth: .infinity, alignment: .leading)`,
    `lineLimit(1)`, `truncationMode(.tail)`)
  - bracket: 64 (`bracketName ?? ""`)
  - resultado: 96 (`stageLabel ?? ""`, `lineLimit(2)`, `minimumScaleFactor(0.85)`)
- A reusable `RankingButton(action:)` view also lives in this file: a full-width
  navy pill (`RoundedRectangle`, fill ~`Color(red: 0.10, green: 0.12, blue: 0.30)`,
  thin white-opacity border), `HStack { Image(systemName: "trophy.fill"); Text("Ranking Final") }`
  in white, ~15pt semibold, vertical padding ~14. Exact colors verified/tuned in Xcode.
- A `#Preview` builds a `RankingResponse` with ~6 sample entries spanning
  Gold/Silver/Bronze.

### 3. Button, fetch & presentation — `StandingsView.swift`

- Add state:
  ```swift
  @State private var ranking: RankingResponse?
  @State private var showRanking = false
  ```
- Add a fetch task alongside the existing `.task { await loadStandings() }`:
  ```swift
  .task { ranking = try? await APIService.shared.fetchRanking(for: tournament.id) }
  ```
  Non-blocking and independent of standings loading; on any failure `ranking`
  stays `nil` and no button shows.
- Compute visibility:
  ```swift
  private var showsRankingButton: Bool {
      guard let ranking else { return false }
      return ranking.available && !ranking.ranking.isEmpty
  }
  ```
- Pin the button with `.safeAreaInset(edge: .bottom)` on `StandingsView`'s root,
  so scroll content is automatically inset above it:
  ```swift
  .safeAreaInset(edge: .bottom, spacing: 0) {
      if showsRankingButton, let ranking {
          RankingButton { showRanking = true }
              .padding(.horizontal, AppTheme.Layout.screenPadding)
              .padding(.top, AppTheme.Spacing.small)
              .padding(.bottom, StandingsLayout.tabBarClearance)
              .frame(maxWidth: .infinity)
      }
  }
  .fullScreenCover(isPresented: $showRanking) {
      if let ranking { RankingView(response: ranking) }
  }
  ```
- `StandingsLayout.tabBarClearance`: a documented constant sized to clear the
  container's floating `CustomTabBar` (TabButton 52 + `CustomTabBar` padding 8·2 +
  its `.padding(.bottom, 10)` ≈ 78, plus a small gap). Initial value **84**,
  verified/tuned on-device in Xcode. Because `.safeAreaInset` measures from the
  safe-area bottom, a fixed clearance always clears the bar on every device; only
  the visible gap varies slightly.

## Edge cases

- Fetch fails / `available == false` / empty `ranking` → button never appears
  (guarded by `showsRankingButton`).
- `bracketName` / `stageLabel` null → blank cell (`?? ""`).
- Long `teamName` → truncates with tail ellipsis. Long `stageLabel`
  ("Octavos de Final") → wraps to 2 lines / scales down.
- Modal is only reachable when `ranking` is loaded and non-empty, so it never
  needs its own loading/error/empty state.

## Out of scope

- No export/PDF button (the web mockup has one; explicitly omitted).
- No changes to the podiums/Campeón work from the prior spec.
- No refactor of the container's floating tab bar.

## Files

- **New:** `Brackets/RankingView.swift` — `RankingView`, `RankingRow`,
  `RankingButton`, column-width constants, preview.
- **Modify:** `Brackets/APIService.swift` — `RankingResponse`, `RankingEntry`,
  `fetchRanking`.
- **Modify:** `Brackets/StandingsView.swift` — ranking state, fetch `.task`,
  `showsRankingButton`, `.safeAreaInset` button, `.fullScreenCover`, and the
  `StandingsLayout.tabBarClearance` constant.

## Verification

No unit-test target; verification is Xcode build + previews + manual:

1. `⌘B` builds (`Brackets` scheme).
2. `RankingView` `#Preview` renders the table (columns aligned, alternating rows,
   ✕ button).
3. Manual: on a finished tournament's Standings tab, the "Ranking Final" button
   shows above the tab bar and clears it on a notch and a non-notch device;
   tapping opens the list; ✕ returns to Standings.
4. Manual: on an in-progress tournament (or one returning `available: false`), no
   button appears.
