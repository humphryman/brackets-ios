# Bracket Placeholders Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fill unplayed bracket matchups using each bracket's `game_placeholders` data — seed labels (`team_a`/`team_b`), scheduled date/time, and venue — keyed by `stage` + `bracket_id`.

**Architecture:** Add a `GamePlaceholder` model hung off `BracketInfo`; in `BracketView`, carry placeholder/schedule fields on `BracketMatchup`, resolve them in `buildMatchup` (team precedence: real advancing → seed label → TBD), render seed labels in `teamRow`, and add a compact time+venue footer to the card with a uniform bumped card height so the connector tree stays aligned.

**Tech Stack:** SwiftUI (iOS 17+), pure Swift, `AppTheme` tokens. No third-party deps.

**Depends on:** the `multi-bracket-tabs` branch (provides `BracketInfo`, `selectedBracket`, per-bracket rendering). Branch this work off `multi-bracket-tabs`.

## Global Constraints

- **No terminal build/test tooling** — verify in **Xcode**: build **⌘B** + inspect the Bracket tab. No XCTest step.
- **Dark mode only**; UI text Spanish; `es_MX`; `AppConfig.DateTime.apiTimeZone`.
- Placeholder key: match by `stage` (via existing `stageMatches`) **and** `bracket_id == slot`.
- Team precedence on unplayed slots: **real advancing team (propagation) → seed label (`team_a`/`team_b`) → "TBD"**.
- Footer shows whenever `scheduledTime != nil` (sourced from the game when present, else the placeholder); date/time format `d MMM · h:mm a` (e.g. `1 jul · 2:00 PM`) + `venue.name`.
- Uniform card height: bump `matchupCardHeight` 110 → 140 and give cards an explicit fixed height; connector/spacing math already derives from that constant.
- Do **not** run `git commit` unless the executor is explicitly authorized; commit steps are written for completeness — otherwise leave changes uncommitted.
- SourceKit "cannot find X in scope" cross-file errors are false positives (same-module); ignore them.

---

## File Structure

- **Modify `Brackets/Game.swift`:** add `GamePlaceholder` + `BracketInfo.gamePlaceholders`.
- **Modify `Brackets/BracketView.swift`:** `BracketMatchup` fields; `placeholderForSlot`; `buildMatchup` precedence + schedule; `teamRow` seed-label fallback; `matchupCard` footer + height.

---

### Task 1: Model — `GamePlaceholder` + `BracketInfo.gamePlaceholders`

**Files:**
- Modify: `Brackets/Game.swift`

**Interfaces:**
- Produces: `struct GamePlaceholder` (`stage: String?`, `bracketId: Int?`, `teamA: String?`, `teamB: String?`, `gameTime: Date?`, `venue: Venue?`); `BracketInfo.gamePlaceholders: [GamePlaceholder]?`.

- [ ] **Step 1: Add the `GamePlaceholder` struct**

Add just above `struct BracketInfo` in `Game.swift`:

```swift
struct GamePlaceholder: Codable, Sendable {
    let stage: String?
    let bracketId: Int?
    let teamA: String?
    let teamB: String?
    let gameTime: Date?
    let venue: Venue?

    enum CodingKeys: String, CodingKey {
        case stage
        case bracketId = "bracket_id"
        case teamA = "team_a"
        case teamB = "team_b"
        case gameTime = "game_time"
        case venue
    }
}
```

- [ ] **Step 2: Add `gamePlaceholders` to `BracketInfo`**

In `struct BracketInfo`, add the property after `let typeLabel: String?`:

```swift
    let gamePlaceholders: [GamePlaceholder]?
```

and add its coding key:

```swift
    enum CodingKeys: String, CodingKey {
        case name, position, type
        case typeLabel = "type_label"
        case gamePlaceholders = "game_placeholders"
    }
}
```

- [ ] **Step 3: Build**

Run: **⌘B**. Expected: builds. `BracketInfo` decodes `game_placeholders` when present, tolerates absence (optional). `gameTime` parses via the games response's existing `.custom` date strategy. No behavior change yet.

- [ ] **Step 4: Commit** (only if authorized)

```bash
git add Brackets/Game.swift
git commit -m "Add GamePlaceholder model to BracketInfo"
```

---

### Task 2: Placement logic — seed labels + schedule on matchups

**Files:**
- Modify: `Brackets/BracketView.swift`

**Interfaces:**
- Consumes: `GamePlaceholder`, `BracketInfo.gamePlaceholders` (Task 1); `selectedBracket`, `stageMatches`, `gameForSlot`, `propagatedPair`.
- Produces: `BracketMatchup` gains `homePlaceholder`/`awayPlaceholder`/`scheduledTime`/`venue`; `placeholderForSlot(stage:slot:)`; `buildMatchup` sets them; `teamRow` shows seed labels.

- [ ] **Step 1: Add fields to `BracketMatchup`**

In `struct BracketMatchup`, add the four defaulted fields after `let game: Game?`:

```swift
    var homePlaceholder: String? = nil
    var awayPlaceholder: String? = nil
    var scheduledTime: Date? = nil
    var venue: Venue? = nil
```

- [ ] **Step 2: Add `placeholderForSlot`**

In `BracketView`, add near `gameForSlot(stage:slot:)`:

```swift
    private func placeholderForSlot(stage: String, slot: Int) -> GamePlaceholder? {
        selectedBracket?.gamePlaceholders?.first { ph in
            guard let phStage = ph.stage else { return false }
            return stageMatches(gameStage: phStage, target: stage) && ph.bracketId == slot
        }
    }
```

- [ ] **Step 3: Replace `buildMatchup` to set schedule + seed labels**

Replace the entire `buildMatchup(stage:slot:propagation:)` method with:

```swift
    private func buildMatchup(stage: String, slot: Int, propagation: (home: Team?, away: Team?)?) -> BracketMatchup {
        if let game = gameForSlot(stage: stage, slot: slot) {
            return BracketMatchup(
                homeTeam: game.homeTeam,
                homeScore: game.homeScore,
                homeIsWinner: game.isFinished && game.winner?.id == game.homeTeam?.id,
                awayTeam: game.awayTeam,
                awayScore: game.awayScore,
                awayIsWinner: game.isFinished && game.winner?.id == game.awayTeam?.id,
                hasGame: true,
                game: game,
                scheduledTime: game.gameTime,
                venue: game.venue
            )
        }

        let placeholder = placeholderForSlot(stage: stage, slot: slot)
        return BracketMatchup(
            homeTeam: propagation?.home,
            homeScore: nil,
            homeIsWinner: false,
            awayTeam: propagation?.away,
            awayScore: nil,
            awayIsWinner: false,
            hasGame: false,
            game: nil,
            homePlaceholder: propagation?.home == nil ? placeholder?.teamA : nil,
            awayPlaceholder: propagation?.away == nil ? placeholder?.teamB : nil,
            scheduledTime: placeholder?.gameTime,
            venue: placeholder?.venue
        )
    }
```

- [ ] **Step 4: Add a seed-label fallback to `teamRow`**

Replace the entire `teamRow(team:score:isWinner:hasGame:)` method with a version that takes a `placeholderName` and uses it as the middle fallback:

```swift
    private func teamRow(team: Team?, score: Int?, isWinner: Bool, hasGame: Bool, placeholderName: String? = nil) -> some View {
        let displayName = team?.name ?? placeholderName ?? "TBD"
        let nameColor: Color = {
            if team != nil { return isWinner ? AppTheme.Colors.primaryText : Color(white: 0.5) }
            if placeholderName != nil { return Color(white: 0.45) }
            return Color(white: 0.25)
        }()

        return HStack(spacing: 6) {
            // Team logo
            if let team = team {
                teamLogoView(team: team, isWinner: isWinner)
            } else {
                placeholderLogo()
            }

            // Team name — fills all available space
            Text(displayName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(nameColor)
                .lineLimit(2)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Score
            Text(score.map { "\($0)" } ?? "-")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(isWinner ? AppTheme.Colors.accent : (score != nil ? AppTheme.Colors.primaryText : Color(white: 0.3)))
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(isWinner ? AppTheme.Colors.accent.opacity(0.2) : Color(white: 0.15))
                )
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }
```

- [ ] **Step 5: Pass the seed labels from `matchupCard`**

In `matchupCard`, update the two `teamRow(...)` calls to pass the placeholder names:

```swift
            teamRow(
                team: matchup.homeTeam,
                score: matchup.homeScore,
                isWinner: matchup.homeIsWinner,
                hasGame: matchup.hasGame,
                placeholderName: matchup.homePlaceholder
            )
```

and:

```swift
            teamRow(
                team: matchup.awayTeam,
                score: matchup.awayScore,
                isWinner: matchup.awayIsWinner,
                hasGame: matchup.hasGame,
                placeholderName: matchup.awayPlaceholder
            )
```

- [ ] **Step 6: Build and verify in Xcode**

Run: **⌘B**, open the Bracket tab on a multi-bracket tournament with unplayed matchups.
Expected: builds. Unplayed first-round matchups now show seed labels (e.g. "1° Lugar" vs "8° Lugar") instead of "TBD"; matchups whose teams have advanced from a played prior round still show the real teams (precedence). Legacy single-bracket tournaments (no `brackets` array) are unchanged. No footer yet (Task 3).

- [ ] **Step 7: Commit** (only if authorized)

```bash
git add Brackets/BracketView.swift
git commit -m "Fill unplayed bracket slots with placeholder seed labels + schedule"
```

---

### Task 3: Card footer + uniform height

**Files:**
- Modify: `Brackets/BracketView.swift`

**Interfaces:**
- Consumes: `BracketMatchup.scheduledTime`/`venue` (Task 2); `matchupCardHeight`, `matchupCard`.
- Produces: a `matchupFooter` view; `matchupCardHeight = 140`; explicit card height.

- [ ] **Step 1: Bump the card height constant**

In `BracketView`, change:

```swift
    private let matchupCardHeight: CGFloat = 110
```

to:

```swift
    private let matchupCardHeight: CGFloat = 140
```

- [ ] **Step 2: Add the footer view + formatter**

Add to `BracketView`:

```swift
    private func matchupFooter(time: Date, venue: Venue?) -> some View {
        VStack(spacing: 1) {
            Text(Self.footerDateFormatter.string(from: time))
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Color(white: 0.5))
            if let venue {
                Text(venue.name)
                    .font(.system(size: 9))
                    .foregroundStyle(Color(white: 0.45))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
        .padding(.top, 4)
        .padding(.bottom, 6)
    }

    private static let footerDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_MX")
        f.timeZone = AppConfig.DateTime.apiTimeZone
        f.dateFormat = "d MMM · h:mm a"
        return f
    }()
```

- [ ] **Step 3: Render the footer + fix card height in `matchupCard`**

In `matchupCard`, the `card` view is a `VStack(spacing: 0) { homeTeamRow; divider; awayTeamRow }` with `.frame(width: matchupCardWidth)`. Add the footer inside that `VStack` (after the away `teamRow`) and change the frame to a fixed height with alignment:

```swift
        let card = VStack(spacing: 0) {
            // Home team row
            teamRow(
                team: matchup.homeTeam,
                score: matchup.homeScore,
                isWinner: matchup.homeIsWinner,
                hasGame: matchup.hasGame,
                placeholderName: matchup.homePlaceholder
            )

            Rectangle()
                .fill(Color(white: 0.2))
                .frame(height: 1)
                .padding(.horizontal, 8)

            // Away team row
            teamRow(
                team: matchup.awayTeam,
                score: matchup.awayScore,
                isWinner: matchup.awayIsWinner,
                hasGame: matchup.hasGame,
                placeholderName: matchup.awayPlaceholder
            )

            if let time = matchup.scheduledTime {
                matchupFooter(time: time, venue: matchup.venue)
            }
        }
        .frame(width: matchupCardWidth, height: matchupCardHeight, alignment: matchup.scheduledTime == nil ? .center : .top)
        .background(Color(white: 0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(strokeColor, lineWidth: strokeWidth)
        )
        .overlay(alignment: .top) {
            if isLive {
                BracketLiveBadge()
                    .offset(y: -9)
            }
        }
```

(Only the two `teamRow` calls' `placeholderName:` args, the `if let time = matchup.scheduledTime` footer, and the `.frame(width:height:alignment:)` line change; the `let strokeColor`/`strokeWidth`/`defaultStroke` bindings above `let card` and the `NavigationLink` wrapping below it are unchanged.)

- [ ] **Step 4: Build and verify in Xcode**

Run: **⌘B**, open the Bracket tab.
Expected: builds. Every matchup with a scheduled time (placeholder or real game) shows a compact footer: `1 jul · 2:00 PM` over the venue name. All cards are the same height and the connector lines still meet the cards cleanly (uniform 140pt height). Footerless cards (no schedule) center their teams so connectors still point at them. An octavos bracket scrolls but stays aligned.

- [ ] **Step 5: Commit** (only if authorized)

```bash
git add Brackets/BracketView.swift
git commit -m "Add scheduled time + venue footer to bracket cards"
```

---

## Self-Review

**Spec coverage:**
- `GamePlaceholder` + `BracketInfo.gamePlaceholders` → Task 1. ✔
- `BracketMatchup` fields → Task 2 Step 1. ✔
- `placeholderForSlot` (stage + bracket_id key, within `selectedBracket`) → Task 2 Step 2. ✔
- `buildMatchup` precedence (real → seed → TBD) + `scheduledTime`/`venue` from game-or-placeholder → Task 2 Step 3. ✔
- `teamRow` seed-label fallback → Task 2 Steps 4–5. ✔
- Footer (shown when `scheduledTime != nil`, `d MMM · h:mm a` + venue.name) → Task 3 Steps 2–3. ✔
- Uniform explicit height, `matchupCardHeight = 140`, connector math auto-adjust → Task 3 Steps 1, 3. ✔
- Legacy no-bracket fallback unchanged (`selectedBracket` nil → no placeholders) → Task 2 Step 2. ✔

**Placeholder scan:** No TBD/TODO in requirements; every step carries complete code. ("TBD" appears only as the on-screen fallback string, which is correct.)

**Type consistency:** `GamePlaceholder`, `gamePlaceholders`, `placeholderForSlot(stage:slot:)`, `BracketMatchup.homePlaceholder/awayPlaceholder/scheduledTime/venue`, `teamRow(...placeholderName:)`, `matchupFooter(time:venue:)`, `matchupCardHeight` are consistent across tasks. `buildMatchup` uses the `BracketMatchup` memberwise init with the new defaulted trailing fields (game branch omits the placeholder-name fields; placeholder branch passes all) — valid because they have defaults.
