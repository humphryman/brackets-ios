# Bracket Morph Navigation — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the bracket tab's integer horizontal paging with an Apple Sports–style windowed, morphing navigation driven by a single continuous `windowProgress` value and a draggable stage selector.

**Architecture:** Spacing/top-offset become continuous functions of each round's distance from the window's left edge (`d = roundIndex − windowProgress`, clamped to `[0,1]`); the rounds HStack is offset by `−windowProgress × columnWidth`. Animating/`dragging` `windowProgress` morphs the shared middle round from tree-spread to condensed while the stack slides. A new `StageSelector` and a content drag both drive the same `windowProgress`. Cards, connectors, data, and live refresh are untouched. Two tasks: (1) the isolated selector view, (2) the engine rewrite + wiring.

**Tech Stack:** Swift 5 / SwiftUI (iOS 17+). No third-party deps.

## Global Constraints

- **No test target / no terminal build tools.** Per `CLAUDE.md`, verification is: open `Brackets.xcodeproj`, build with ⌘B (expect **Build Succeeded**), and inspect SwiftUI `#Preview`s / run manually. No `xcodebuild`/`pytest`.
- **Do NOT change any card/connector/badge styling** or data loading / live refresh. Navigation + column layout only.
- **Dark mode only**; accent lime `AppTheme.Colors.accent`. UI text Spanish.
- **Stage labels:** `16vos · 8vos · 4tos · Semis · Final`. Never a GS entry.
- **Constants (unchanged values):** `matchupCardWidth = 180`, `matchupCardHeight = 153`, `connectorWidth = 36`, `columnWidth = matchupCardWidth + connectorWidth = 216`, `baseSpacing = (activeType == "semifinals") ? 80 : 24`.
- **Layout formulas (verbatim):**
  - `d(r) = min(max(CGFloat(r) - windowProgress, 0), 1)`
  - `spacing(d) = (baseSpacing + cardH) * pow(2, d) - cardH`
  - `topPad(d) = step0 * (pow(2, d) - 1) / 2`, where `step0 = cardH + baseSpacing`
  - content xOffset = `-windowProgress * columnWidth + AppTheme.Layout.screenPadding`
- **Commit messages** end with:
  `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`
- Do not commit until the user authorizes; the user's norm is "uncommitted unless authorized."

---

### Task 1: `StageSelector` view

Self-contained draggable stage selector. Additive — not wired into `BracketView`'s body yet, so the build stays green and the view is exercised via its own preview.

**Files:**
- Modify: `Brackets/BracketView.swift` (append the `StageSelector` struct + a `#Preview` near the end, after the `BracketLiveBadge` struct)

**Interfaces:**
- Consumes: `AppTheme.Colors.accent`, `AppTheme.Colors.primaryText`.
- Produces: `struct StageSelector: View` with `init(labels: [String], windowProgress: Binding<CGFloat>, maxWindow: CGFloat)`.

- [ ] **Step 1: Add the `StageSelector` struct and preview**

At the end of `Brackets/BracketView.swift` (after the closing brace of `private struct BracketLiveBadge`), append:

```swift
// MARK: - Stage Selector

/// Apple Sports–style stage bar: a row of stage labels with a draggable 2-wide
/// highlight marking the two stages currently visible. Bound to the same
/// `windowProgress` the bracket content uses, so selector-drag and content-swipe
/// stay in sync.
struct StageSelector: View {
    let labels: [String]
    @Binding var windowProgress: CGFloat
    let maxWindow: CGFloat

    @State private var dragStart: CGFloat?

    var body: some View {
        GeometryReader { geo in
            let n = max(labels.count, 1)
            let segW = geo.size.width / CGFloat(n)
            let h = geo.size.height

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(white: 0.10))

                // 2-wide highlight window with chevron affordances
                HStack {
                    Image(systemName: "chevron.left")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(maxWindow > 0 ? Color(white: 0.7) : .clear)
                .padding(.horizontal, 8)
                .frame(width: segW * 2, height: h - 8)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.06)))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(AppTheme.Colors.accent, lineWidth: 2))
                .offset(x: windowProgress * segW)

                // Stage labels (drawn over the highlight)
                HStack(spacing: 0) {
                    ForEach(Array(labels.enumerated()), id: \.offset) { i, label in
                        Text(label)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(isActive(i) ? AppTheme.Colors.primaryText : Color(white: 0.45))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(width: segW)
                    }
                }
            }
            .frame(height: h)
            .contentShape(Rectangle())
            .gesture(dragGesture(segW: segW))
        }
        .frame(height: 44)
    }

    private func isActive(_ i: Int) -> Bool {
        CGFloat(i) >= windowProgress - 0.5 && CGFloat(i) <= windowProgress + 1.5
    }

    private func dragGesture(segW: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 5)
            .onChanged { value in
                guard maxWindow > 0, segW > 0 else { return }
                let start = dragStart ?? windowProgress
                if dragStart == nil { dragStart = start }
                windowProgress = min(max(start + value.translation.width / segW, 0), maxWindow)
            }
            .onEnded { _ in
                dragStart = nil
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    windowProgress = min(max(windowProgress.rounded(), 0), maxWindow)
                }
            }
    }
}

#Preview("Stage selector") {
    struct Wrap: View {
        @State var progress: CGFloat = 0
        var body: some View {
            StageSelector(
                labels: ["16vos", "8vos", "4tos", "Semis", "Final"],
                windowProgress: $progress,
                maxWindow: 3
            )
            .padding()
        }
    }
    return ZStack { Color.black.ignoresSafeArea(); Wrap() }
}
```

- [ ] **Step 2: Verify build and preview**

Open `Brackets.xcodeproj`, build (⌘B). Expected: **Build Succeeded**.
Open the **"Stage selector"** preview: five labels; a lime-outlined 2-wide highlight over `16vos·8vos`; dragging the bar moves the highlight and snaps to whole stages on release; the two labels under the highlight are bright, the rest dim.

- [ ] **Step 3: Commit**

```bash
git add Brackets/BracketView.swift
git commit -m "feat: add StageSelector for bracket navigation

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: Continuous-`windowProgress` layout engine + wire selector

Rewrites the navigation/layout section of `BracketView` to the morph engine and wires in the `StageSelector` from Task 1. This is one atomic change (the pieces are interdependent); after it, the feature works end-to-end.

**Files:**
- Modify: `Brackets/BracketView.swift` (state ~10-18; layout constants ~80-88; `bracketPager`/`staticBracket`/`pagedBracket` ~90-154; `bracketHeaders` ~159-169; `roundColumn` ~191-230; `connectorsColumn` ~425-439; `matchupSpacing`/`topPadding` ~493-502; `body` content branch ~42-70)

**Interfaces:**
- Consumes: `StageSelector(labels:windowProgress:maxWindow:)` (Task 1); existing `rounds`, `roundColumn`, `connectorsColumn`, `roundHeaderLabel`, `matchupCard`, `activeType`, `AppTheme`.
- Produces: no new outward interface.

- [ ] **Step 1: Swap paging state for `windowProgress`**

In `Brackets/BracketView.swift`, replace:

```swift
    @State private var currentPage: Int = 0
    @State private var dragOffset: CGFloat = 0
```

with:

```swift
    @State private var windowProgress: CGFloat = 0
    @State private var gestureStartProgress: CGFloat? = nil
```

- [ ] **Step 2: Replace layout constants + spacing helpers**

Replace the layout-constants block:

```swift
    // MARK: - Layout Constants

    private let matchupCardWidth: CGFloat = 180
    private let matchupCardHeight: CGFloat = 153
    private let connectorWidth: CGFloat = 36

    private var roundColumnWidth: CGFloat {
        matchupCardWidth + connectorWidth
    }
```

with:

```swift
    // MARK: - Layout Constants

    private let matchupCardWidth: CGFloat = 180
    private let matchupCardHeight: CGFloat = 153
    private let connectorWidth: CGFloat = 36

    private var columnWidth: CGFloat {
        matchupCardWidth + connectorWidth
    }

    // MARK: - Windowed Layout Math

    private var baseSpacing: CGFloat { activeType == "semifinals" ? 80 : 24 }
    private var step0: CGFloat { matchupCardHeight + baseSpacing }
    private var maxWindow: CGFloat { CGFloat(max(0, rounds.count - 2)) }

    /// A round's clamped distance from the window's left edge (0 = condensed left
    /// column, 1 = spread right column). Only the shared middle round has a
    /// fractional distance mid-transition, so only it morphs.
    private func distance(_ roundIndex: Int) -> CGFloat {
        min(max(CGFloat(roundIndex) - windowProgress, 0), 1)
    }

    private func spacing(_ d: CGFloat) -> CGFloat {
        (baseSpacing + matchupCardHeight) * pow(2, d) - matchupCardHeight
    }

    private func topPad(_ d: CGFloat) -> CGFloat {
        step0 * (pow(2, d) - 1) / 2
    }

    private func roundLabel(_ name: String) -> String {
        switch name {
        case "16vos de Final": return "16vos"
        case "Octavos de Final": return "8vos"
        case "Cuartos de Final": return "4tos"
        case "Semifinal": return "Semis"
        case "Final": return "Final"
        default: return name
        }
    }
```

- [ ] **Step 3: Delete the old paging/header helpers**

Delete these methods entirely (they are replaced in Steps 4–6):
- `bracketPager(pageWidth:)`
- `staticBracket()`
- `pagedBracket(pageWidth:)`
- `bracketHeaders` (the computed property with the top capsule header row)
- `matchupSpacing(for:)`
- `topPadding(for:)`

Keep `roundHeaderLabel(_:)` (still used by the last-round inline title in `roundColumn`) and `bracketBody` will be removed in Step 5.

- [ ] **Step 4: Replace the body content branch + add the morph content**

In `body`, replace the `else` content branch:

```swift
            } else {
                GeometryReader { geo in
                    bracketPager(pageWidth: geo.size.width)
                }
            }
```

with:

```swift
            } else {
                bracketContent()
            }
```

And update the `ChipCarousel` `onChange` from:

```swift
                    .onChange(of: selectedBracketName) {
                        currentPage = 0
                        dragOffset = 0
                    }
```

to:

```swift
                    .onChange(of: selectedBracketName) {
                        windowProgress = 0
                    }
```

Then add these three methods (place them where `bracketPager`/`staticBracket`/`pagedBracket` were, under a `// MARK: - Content`):

```swift
    // MARK: - Content

    @ViewBuilder
    private func bracketContent() -> some View {
        let labels = rounds.map { roundLabel($0.name) }
        VStack(spacing: 0) {
            StageSelector(labels: labels, windowProgress: $windowProgress, maxWindow: maxWindow)
                .padding(.horizontal, AppTheme.Layout.screenPadding)
                .padding(.top, AppTheme.Spacing.medium)
                .padding(.bottom, 12)

            morphingBracket()
        }
    }

    private func morphingBracket() -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            HStack(alignment: .top, spacing: 0) {
                ForEach(Array(rounds.enumerated()), id: \.element.name) { roundIndex, round in
                    roundColumn(round: round, roundIndex: roundIndex)
                }
            }
            .padding(.bottom, 100)
            .offset(x: -windowProgress * columnWidth + AppTheme.Layout.screenPadding)
        }
        .clipped()
        .simultaneousGesture(windowDragGesture())
    }

    private func windowDragGesture() -> some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                guard maxWindow > 0 else { return }
                if abs(value.translation.width) > abs(value.translation.height) {
                    let start = gestureStartProgress ?? windowProgress
                    if gestureStartProgress == nil { gestureStartProgress = start }
                    windowProgress = min(max(start - value.translation.width / columnWidth, 0), maxWindow)
                }
            }
            .onEnded { value in
                let start = gestureStartProgress ?? windowProgress
                gestureStartProgress = nil
                guard maxWindow > 0 else { return }
                let target: CGFloat
                if abs(value.predictedEndTranslation.width) > columnWidth * 0.5 {
                    target = value.translation.width < 0 ? start + 1 : start - 1
                } else {
                    target = windowProgress.rounded()
                }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                    windowProgress = min(max(target, 0), maxWindow)
                }
            }
    }
```

- [ ] **Step 5: Rewrite `roundColumn` to use the continuous distance**

Replace the whole `roundColumn(round:roundIndex:)` method with:

```swift
    private func roundColumn(round: BracketRound, roundIndex: Int) -> some View {
        let d = distance(roundIndex)
        let topOffset = topPad(d)
        let spacing = spacing(d)
        let isLastRound = roundIndex == rounds.count - 1

        return HStack(alignment: .top, spacing: 0) {
            // Matchup cards (+ Tercer Lugar stacked below, if present)
            VStack(spacing: 0) {
                if isLastRound {
                    roundHeaderLabel(round)
                        .frame(width: matchupCardWidth, alignment: .leading)
                        .padding(.bottom, 10)
                }

                VStack(spacing: spacing) {
                    ForEach(Array(round.matchups.enumerated()), id: \.offset) { _, matchup in
                        matchupCard(matchup: matchup)
                    }
                }

                if let third = round.thirdPlace {
                    Spacer().frame(height: 60)
                    Text("3er Lugar")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color(white: 0.45))
                        .frame(width: matchupCardWidth, alignment: .center)
                    Spacer().frame(height: 6)
                    matchupCard(matchup: third)
                }
            }
            .padding(.top, topOffset)

            // Connector lines to next round
            if roundIndex < rounds.count - 1 {
                connectorsColumn(roundIndex: roundIndex, matchups: round.matchups)
                    .padding(.top, topOffset)
            }
        }
    }
```

Also delete the now-unused `bracketBody` computed property (its `HStack`-of-`roundColumn`s role now lives in `morphingBracket`).

- [ ] **Step 6: Rewrite `connectorsColumn` to use the continuous distance**

Replace the first line of `connectorsColumn(roundIndex:matchups:)` that reads:

```swift
        let spacing = matchupSpacing(for: roundIndex)
```

with:

```swift
        let spacing = spacing(distance(roundIndex))
```

(The rest of `connectorsColumn` and all of `connectorPair` stay exactly as-is.)

- [ ] **Step 7: Verify build and behavior**

Build (⌘B). Expected: **Build Succeeded** (no references to `currentPage`, `dragOffset`, `bracketPager`, `staticBracket`, `pagedBracket`, `bracketHeaders`, `bracketBody`, `matchupSpacing`, `topPadding`, or `roundColumnWidth` remain).

Run the app on a playoffs tournament and, for the bracket types available, confirm:
- The stage selector shows the correct Spanish labels and a 2-wide highlight.
- Dragging the content horizontally moves the window and morphs the middle round (left condenses / right spreads), tracking the finger; releasing snaps to a stage pair.
- Dragging the selector does the same and stays in sync with the content.
- Vertical scrolling still works within a window.
- Connectors stay attached to card centers through the morph.
- The last window shows Final + 3er Lugar; live badges and card taps work.
- A semifinals-only bracket shows two fixed stages with no paging.

- [ ] **Step 8: Commit**

```bash
git add Brackets/BracketView.swift
git commit -m "feat: windowed morphing bracket navigation

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Manual QA (after Task 2)

Exercise each bracket type (`dieciseisavos`→5 stages/4 windows, `octavos`→4/3,
`quarterfinals`→3/2, `semifinals`→2/1) on a notch and non-notch simulator:
morph tracks the drag, selector/content stay in sync, vertical scroll works,
connectors stay attached, third-place/live/taps intact, and no card/connector
styling changed.

## Self-Review Notes

- **Spec coverage:** stage selector w/ Spanish labels + 2-wide highlight (Task 1;
  Task 2 Step 4 wires labels) ✓; never-GS (labels come from knockout `rounds`) ✓;
  two-stages-at-a-time via `columnWidth` offset + `d`-clamped spacing (Task 2 Steps
  2,4,5,6) ✓; drag content OR selector both drive `windowProgress` (Task 1 gesture +
  Task 2 `windowDragGesture`) ✓; left-condense/right-spread morph via
  `spacing(d)`/`topPad(d)` (Step 2) ✓; interactive morph (onChanged updates
  `windowProgress`) ✓; connectors morph (Step 6) ✓; no style changes (cards/
  `connectorPair`/badge untouched) ✓; 2-stage edge case (`maxWindow == 0`) ✓.
- **Type consistency:** `StageSelector(labels:windowProgress:maxWindow:)` matches
  between Task 1 and its Task 2 call site; `distance`/`spacing`/`topPad`/`step0`/
  `baseSpacing`/`columnWidth`/`maxWindow`/`roundLabel` all defined in Step 2 and
  used in Steps 4–6; removed symbols (`currentPage`, `dragOffset`, `bracketPager`,
  `staticBracket`, `pagedBracket`, `bracketHeaders`, `bracketBody`,
  `matchupSpacing`, `topPadding`, `roundColumnWidth`) have no remaining references.
- **No placeholders:** every code step is complete; verification is Xcode build +
  named preview + manual (no fabricated CLI, per the no-test-target constraint).
