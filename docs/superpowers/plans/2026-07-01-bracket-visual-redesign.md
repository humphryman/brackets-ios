# Bracket Visual Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restyle the playoff bracket to match the mockup — round-header pill + date, redesigned matchup cards (circular avatars + name + large score), winner highlighting, per-card clock+date+time footer with venue Maps link, and green connector accents for advanced teams.

**Architecture:** All in `Brackets/BracketView.swift`. Redesign `teamRow` (avatar/name/score + winner band); restructure `matchupCard` footer (clock+date+time on top of the venue Maps link) and bump the uniform card height; restyle `bracketHeaders` + the Final inline title as pill+date; add a green accent to the connector segments feeding advanced teams. Built so each task compiles.

**Tech Stack:** SwiftUI (iOS 17+), pure Swift, `AppTheme` tokens.

**Depends on:** the `bracket-placeholders` branch. Branch this work off `bracket-placeholders`.

## Global Constraints

- **No terminal build/test tooling** — verify in **Xcode**: build **⌘B** + inspect the Bracket tab. No XCTest step.
- Dark mode only; UI text Spanish; `es_MX`; `AppConfig.DateTime.apiTimeZone`.
- **Colors:** card bg `Color(white: 0.09)`, radius 14; round pill fill `Color(white: 0.13)`, text `Color(white: 0.6)` 11pt bold uppercase tracking 0.5; header/footer gray `Color(white: 0.4)`; winner → avatar `AppTheme.Colors.accent` + `AppTheme.Colors.accentText` initials, name `primaryText` bold, score `accent`, row band `accent.opacity(0.10)`; neutral/loser → avatar `Color(white: 0.18)` + `Color(white: 0.5)` initials, name `Color(white: 0.55)`, score `Color(white: 0.5)`, unplayed score `"-"` `Color(white: 0.3)`; connector gray `Color(white: 0.25)`, advanced `AppTheme.Colors.accent`.
- **Footer:** `clock` icon + `d MMM · h:mm a` (`amSymbol`/`pmSymbol` = `"AM"`/`"PM"`) → `29 jun · 8:00 AM`; venue line = Maps link (accent + `mappin.and.ellipse`) when `venue.googleMapsURL != nil`, else gray text.
- **Round date** = earliest `scheduledTime` among the round's matchups (+ thirdPlace); format `d MMM` → `29 jun`.
- **Winner highlighting** from `homeIsWinner`/`awayIsWinner`; unplayed matchups (no winner) render both rows neutral, no band.
- Avatars are **initials only** (no logo images).
- Do **not** run `git commit` unless the executor is explicitly authorized; commit steps are for completeness — otherwise leave changes uncommitted.
- SourceKit "cannot find X in scope" cross-file errors are false positives; ignore them.

---

## File Structure

- **Modify `Brackets/BracketView.swift`:** `teamRow` + `teamAvatar` (Task 1, remove old logo helpers); `matchupCard` footer + `matchupFooter` + `footerDateFormatter` + `matchupCardHeight` (Task 2); `bracketHeaders` + Final inline header + `roundHeaderLabel` + `roundDate`/`roundDateFormatter` (Task 3); `connectorsColumn`/`connectorPair` accent (Task 4).

---

### Task 1: Team row redesign (avatar + name + large score + winner band)

**Files:**
- Modify: `Brackets/BracketView.swift`

**Interfaces:**
- Consumes: `BracketMatchup` fields via `matchupCard`'s existing `teamRow(...)` calls.
- Produces: redesigned `teamRow(team:score:isWinner:hasGame:placeholderName:)` + private `teamAvatar(name:isWinner:hasTeam:)`. Removes `teamLogoView`, `logoPlaceholderWithInitials`, `placeholderLogo`, `teamLogoSize`.

- [ ] **Step 1: Replace `teamRow` with the avatar/name/score version**

Replace the entire `teamRow(team:score:isWinner:hasGame:placeholderName:)` method with:

```swift
    private func teamRow(team: Team?, score: Int?, isWinner: Bool, hasGame: Bool, placeholderName: String? = nil) -> some View {
        let displayName = team?.name ?? placeholderName ?? "TBD"
        let hasTeam = team != nil || placeholderName != nil
        let nameColor: Color = isWinner ? AppTheme.Colors.primaryText : (hasTeam ? Color(white: 0.55) : Color(white: 0.3))
        let scoreText = score.map { "\($0)" } ?? "-"
        let scoreColor: Color = isWinner ? AppTheme.Colors.accent : (score != nil ? Color(white: 0.5) : Color(white: 0.3))

        return HStack(spacing: 8) {
            teamAvatar(name: displayName, isWinner: isWinner, hasTeam: hasTeam)

            Text(displayName)
                .font(.system(size: 14, weight: isWinner ? .bold : .semibold))
                .foregroundStyle(nameColor)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(scoreText)
                .font(.system(size: 20, weight: .heavy))
                .foregroundStyle(scoreColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isWinner ? AppTheme.Colors.accent.opacity(0.10) : Color.clear)
                .padding(.horizontal, 4)
        )
    }

    private func teamAvatar(name: String, isWinner: Bool, hasTeam: Bool) -> some View {
        let words = name.split(separator: " ")
        let initials: String = words.count >= 2
            ? String(words[0].prefix(1) + words[1].prefix(1)).uppercased()
            : String(name.prefix(2)).uppercased()
        return Circle()
            .fill(isWinner ? AppTheme.Colors.accent : Color(white: 0.18))
            .frame(width: 30, height: 30)
            .overlay(
                Text(initials)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(isWinner ? AppTheme.Colors.accentText : Color(white: 0.5))
            )
    }
```

- [ ] **Step 2: Remove the now-unused logo helpers**

Delete these three methods and the constant, all now unused (only `teamRow` referenced them):
- `private func teamLogoView(team:isWinner:) -> some View { … }`
- `private func logoPlaceholderWithInitials(name:isWinner:) -> some View { … }`
- `private func placeholderLogo() -> some View { … }`
- `private let teamLogoSize: CGFloat = 40`

- [ ] **Step 3: Build and verify in Xcode**

Run: **⌘B**, open the Bracket tab.
Expected: builds with no references to `teamLogoView`/`placeholderLogo`/`logoPlaceholderWithInitials`/`teamLogoSize` remaining (grep to confirm). Team rows now show a circular initials avatar, name, and a large score; the winner row has a lime avatar + lime score + a subtle green band; loser/neutral rows are gray. (The card still has the old top-date line + divider + venue-at-bottom until Task 2.)

- [ ] **Step 4: Commit** (only if authorized)

```bash
git add Brackets/BracketView.swift
git commit -m "Redesign bracket team row: avatar, name, large score, winner band"
```

---

### Task 2: Card footer (clock + date + time + venue Maps link) and height

**Files:**
- Modify: `Brackets/BracketView.swift`

**Interfaces:**
- Consumes: `BracketMatchup.scheduledTime`/`venue`; existing `venueRow`/`venueContent`.
- Produces: `matchupCard` without the top date line/divider; `matchupFooter(matchup:)`; `footerDateFormatter` with AM/PM symbols; `matchupCardHeight = 150`.

- [ ] **Step 1: Bump the card height**

Change `private let matchupCardHeight: CGFloat = 140` to `= 150`.

- [ ] **Step 2: Rewrite the `card` VStack in `matchupCard`**

Replace the `let card = VStack(spacing: 0) { … }` block (from `let card =` through its `.overlay(alignment: .top) { … }`) with:

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

            // Away team row
            teamRow(
                team: matchup.awayTeam,
                score: matchup.awayScore,
                isWinner: matchup.awayIsWinner,
                hasGame: matchup.hasGame,
                placeholderName: matchup.awayPlaceholder
            )

            // Footer: clock + date + time, and venue (Maps link when coords exist)
            if matchup.scheduledTime != nil || matchup.venue != nil {
                Spacer(minLength: 4)
                matchupFooter(matchup: matchup)
                    .padding(.bottom, 8)
            }
        }
        .frame(width: matchupCardWidth, height: matchupCardHeight, alignment: (matchup.scheduledTime == nil && matchup.venue == nil) ? .center : .top)
        .background(Color(white: 0.09))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(strokeColor, lineWidth: strokeWidth)
        )
        .overlay(alignment: .top) {
            if isLive {
                BracketLiveBadge()
                    .offset(y: -9)
            }
        }
```

(The `isLive`/`defaultStroke`/`strokeColor`/`strokeWidth` bindings above `let card` and the `NavigationLink`/`if let game` wrapping below are unchanged. This removes the old top date `Text`, the `Rectangle` divider, and the old bottom `venueRow` block.)

- [ ] **Step 3: Add `matchupFooter` and update the formatter**

Replace the existing `footerDateFormatter` static property with the AM/PM version and add `matchupFooter` just above it:

```swift
    @ViewBuilder
    private func matchupFooter(matchup: BracketMatchup) -> some View {
        VStack(spacing: 2) {
            if let time = matchup.scheduledTime {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 10))
                    Text(Self.footerDateFormatter.string(from: time))
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(Color(white: 0.4))
            }
            if let venue = matchup.venue {
                venueRow(venue)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 10)
    }

    private static let footerDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_MX")
        f.timeZone = AppConfig.DateTime.apiTimeZone
        f.dateFormat = "d MMM · h:mm a"
        f.amSymbol = "AM"
        f.pmSymbol = "PM"
        return f
    }()
```

- [ ] **Step 4: Build and verify in Xcode**

Run: **⌘B**, open the Bracket tab.
Expected: builds. Cards now show the two team rows, then a footer with a clock icon + `29 jun · 8:00 AM`; a venue line appears below it (green Maps link when the venue has coordinates, else gray). No top date line, no divider between rows. Cards are uniformly 150pt tall and the connector tree still lines up.

- [ ] **Step 5: Commit** (only if authorized)

```bash
git add Brackets/BracketView.swift
git commit -m "Bracket card footer: clock + date + time over venue Maps link"
```

---

### Task 3: Round header pill + date

**Files:**
- Modify: `Brackets/BracketView.swift`

**Interfaces:**
- Consumes: `rounds`, `BracketRound.matchups`/`thirdPlace`, `BracketMatchup.scheduledTime`.
- Produces: `roundHeaderLabel(_:)`, `roundDate(_:)`, `roundDateFormatter`; updated `bracketHeaders` + Final inline title.

- [ ] **Step 1: Add the round-date helper + formatter + header label**

Add to `BracketView` (e.g. near `bracketHeaders`):

```swift
    private func roundDate(_ round: BracketRound) -> Date? {
        var times = round.matchups.compactMap { $0.scheduledTime }
        if let third = round.thirdPlace?.scheduledTime { times.append(third) }
        return times.min()
    }

    private static let roundDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_MX")
        f.timeZone = AppConfig.DateTime.apiTimeZone
        f.dateFormat = "d MMM"
        return f
    }()

    private func roundHeaderLabel(_ round: BracketRound) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(round.name.uppercased())
                .font(.system(size: 11, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(Color(white: 0.6))
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color(white: 0.13)))
            if let date = roundDate(round) {
                Text(Self.roundDateFormatter.string(from: date))
                    .font(.system(size: 12))
                    .foregroundStyle(Color(white: 0.4))
                    .padding(.leading, 4)
            }
        }
    }
```

- [ ] **Step 2: Use the pill header in `bracketHeaders`**

Replace the body of `bracketHeaders`'s `ForEach` `Text(...)` block:

```swift
    private var bracketHeaders: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(rounds.enumerated()), id: \.element.name) { index, round in
                if index < rounds.count - 1 {
                    roundHeaderLabel(round)
                        .frame(width: matchupCardWidth, alignment: .leading)
                        .padding(.trailing, connectorWidth)
                }
            }
        }
    }
```

- [ ] **Step 3: Use the pill header for the Final round (inline)**

In `roundColumn`, replace the `if isLastRound { Text(round.name.uppercased())… }` block with:

```swift
                if isLastRound {
                    roundHeaderLabel(round)
                        .frame(width: matchupCardWidth, alignment: .leading)
                        .padding(.bottom, 10)
                }
```

- [ ] **Step 4: Build and verify in Xcode**

Run: **⌘B**, open the Bracket tab.
Expected: builds. Each round title is a dark capsule pill (e.g. `CUARTOS DE FINAL`) with the round's earliest date (`29 jun`) below it, left-aligned; the sticky behavior is preserved (titles stay pinned while scrolling). The Final column shows the same pill+date inline above its card.

- [ ] **Step 5: Commit** (only if authorized)

```bash
git add Brackets/BracketView.swift
git commit -m "Bracket round headers: pill chip + round date"
```

---

### Task 4: Connector green accent for advanced teams

**Files:**
- Modify: `Brackets/BracketView.swift`

**Interfaces:**
- Consumes: `BracketRound.matchups`, `homeIsWinner`/`awayIsWinner`.
- Produces: `connectorsColumn(roundIndex:matchups:)` + `connectorPair(cardHeight:spacing:topAdvanced:bottomAdvanced:)` + `hasWinner(_:)`.

- [ ] **Step 1: Add `hasWinner` and update the connectors column**

Add:

```swift
    private func hasWinner(_ matchup: BracketMatchup) -> Bool {
        matchup.homeIsWinner || matchup.awayIsWinner
    }
```

Replace `connectorsColumn(roundIndex:matchCount:)` with:

```swift
    private func connectorsColumn(roundIndex: Int, matchups: [BracketMatchup]) -> some View {
        let spacing = matchupSpacing(for: roundIndex)
        let cardH = matchupCardHeight
        let pairCount = matchups.count / 2

        return VStack(spacing: 0) {
            ForEach(0..<max(pairCount, 1), id: \.self) { i in
                let topAdvanced = (2 * i) < matchups.count ? hasWinner(matchups[2 * i]) : false
                let bottomAdvanced = (2 * i + 1) < matchups.count ? hasWinner(matchups[2 * i + 1]) : false
                connectorPair(cardHeight: cardH, spacing: spacing, topAdvanced: topAdvanced, bottomAdvanced: bottomAdvanced)
                    .padding(.bottom, i < pairCount - 1 ? spacing : 0)
            }
        }
        .frame(width: connectorWidth)
    }
```

- [ ] **Step 2: Update the caller in `roundColumn`**

Change the connector call in `roundColumn` from `connectorsColumn(roundIndex: roundIndex, matchCount: round.matchups.count / 2)` to:

```swift
                connectorsColumn(roundIndex: roundIndex, matchups: round.matchups)
```

- [ ] **Step 3: Replace `connectorPair` to draw green accents**

Replace the entire `connectorPair(cardHeight:spacing:)` with:

```swift
    private func connectorPair(cardHeight: CGFloat, spacing: CGFloat, topAdvanced: Bool, bottomAdvanced: Bool) -> some View {
        let pairHeight = cardHeight * 2 + spacing
        let topMid = cardHeight / 2
        let bottomMid = cardHeight + spacing + cardHeight / 2
        let centerY = pairHeight / 2
        let midX = connectorWidth / 2
        let gray = Color(white: 0.25)

        return ZStack {
            // Gray base — all segments
            Path { path in
                path.move(to: CGPoint(x: 0, y: topMid))
                path.addLine(to: CGPoint(x: midX, y: topMid))
                path.addLine(to: CGPoint(x: midX, y: bottomMid))
                path.move(to: CGPoint(x: 0, y: bottomMid))
                path.addLine(to: CGPoint(x: midX, y: bottomMid))
                path.move(to: CGPoint(x: midX, y: centerY))
                path.addLine(to: CGPoint(x: connectorWidth, y: centerY))
            }
            .stroke(gray, lineWidth: 1.5)

            // Green — top input when that source has advanced
            if topAdvanced {
                Path { p in
                    p.move(to: CGPoint(x: 0, y: topMid))
                    p.addLine(to: CGPoint(x: midX, y: topMid))
                }
                .stroke(AppTheme.Colors.accent, lineWidth: 1.5)
            }
            // Green — bottom input when that source has advanced
            if bottomAdvanced {
                Path { p in
                    p.move(to: CGPoint(x: 0, y: bottomMid))
                    p.addLine(to: CGPoint(x: midX, y: bottomMid))
                }
                .stroke(AppTheme.Colors.accent, lineWidth: 1.5)
            }
            // Green — output when at least one source has advanced
            if topAdvanced || bottomAdvanced {
                Path { p in
                    p.move(to: CGPoint(x: midX, y: centerY))
                    p.addLine(to: CGPoint(x: connectorWidth, y: centerY))
                }
                .stroke(AppTheme.Colors.accent, lineWidth: 1.5)
            }
        }
        .frame(width: connectorWidth, height: pairHeight)
    }
```

- [ ] **Step 4: Build and verify in Xcode**

Run: **⌘B**, open the Bracket tab.
Expected: builds. Connector segments whose source matchup has a decided winner render lime-green (feeding the advanced team forward); pending segments stay gray. The tree still aligns.

- [ ] **Step 5: Commit** (only if authorized)

```bash
git add Brackets/BracketView.swift
git commit -m "Bracket connectors: green accent for advanced teams"
```

---

## Self-Review

**Spec coverage:**
- Round header pill + date (sticky) + Final inline → Task 3. ✔
- Card container (bg/radius/border/live badge/navigation) → Task 2 Step 2 (container) + unchanged wrapping. ✔
- Team row avatar + name + large score → Task 1. ✔
- Winner highlighting (band/avatar/score) + neutral-when-unplayed → Task 1. ✔
- Footer clock + date + time + venue Maps link → Task 2 Steps 2–3. ✔
- Connector green accent for advanced → Task 4. ✔
- Height bump + uniform → Task 2 Step 1 + Task 2 Step 2 frame. ✔
- Avatars initials-only; old logo helpers removed → Task 1 Step 2. ✔
- Round date = earliest in round → Task 3 Step 1 (`roundDate`). ✔

**Placeholder scan:** No TBD/TODO in requirements; every step carries complete code. ("TBD" appears only as the on-screen fallback name.)

**Type consistency:** `teamRow(...)` signature unchanged (callers in `matchupCard` untouched by Task 1); `teamAvatar(name:isWinner:hasTeam:)`, `matchupFooter(matchup:)`, `footerDateFormatter`, `roundHeaderLabel(_:)`, `roundDate(_:)`, `roundDateFormatter`, `hasWinner(_:)`, `connectorsColumn(roundIndex:matchups:)`, `connectorPair(cardHeight:spacing:topAdvanced:bottomAdvanced:)` are consistent across tasks. Task 4 changes the connectors' signatures and updates their sole caller in `roundColumn` in the same task.
