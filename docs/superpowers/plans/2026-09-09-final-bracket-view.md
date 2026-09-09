# Final Bracket View Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Render a distinct, animated full-screen view for the `final` bracket type — a Final card (plus an optional Tercer Lugar card) whose four-layer background color is derived from each team's logo.

**Architecture:** A new `Brackets/Final/` module holds pure color/countdown logic, a cached color store, and three SwiftUI views. `BracketView` branches to `FinalBracketView` when the selected bracket's type is `final`, reusing its existing `buildMatchup(stage:slot:propagation:)` to produce the Final and Tercer Lugar matchups. All other bracket types are untouched.

**Tech Stack:** Swift, SwiftUI (iOS 17+), CoreGraphics (logo downscale + pixel sampling), URLSession (logo download), XCTest.

**Spec:** `docs/superpowers/specs/2026-09-09-final-bracket-view-design.md`

## Global Constraints

- Dark mode only; accent color lime green `#C7F24A`.
- All UI text in Spanish; dates via `AppConfig.DateTime.apiTimeZone` (`America/Tijuana`), locale `es_MX`.
- Condensed type is `AppTheme.Typography.condensed(_ weight:size:)` with weights `.regular/.medium/.semibold/.bold/.extraBold` (Barlow Condensed).
- Card corner radius 16; clip the whole layer stack, not each layer.
- Fallback color pair, in order: `#6b7280` (neutral gray), then `#1a2e05` (lime-950). Never the same color on both sides. Fallback values are never run through the "lift" step.
- Extraction runs once per team and is cached for the process lifetime; never per render.
- Blob animation numbers are exact: size 330×400 pt, blur 44, travel ±95 x / ±120 y, scale 1.0→1.35, opacity 0.5→1.0, loop 7s / 9.45s / 4.9s, `easeInOut` autoreversing, `.blendMode(.screen)`, layers rendered in a `.compositingGroup()`.
- Honor `accessibilityReduceMotion` (draw layers 1,2,4 only); stop animating off-screen and when backgrounded (`scenePhase`).
- No terminal build/test tooling — all builds and test runs happen in Xcode (⌘B / ⌘U). "Run test" steps below are executed by the human/reviewer in Xcode.

---

### Task 1: Add `lime950` palette color and a `Color(hex:)` initializer

**Files:**
- Modify: `Brackets/AppTheme.swift` (in `AppTheme.Colors`, near `lime900` ~line 92)
- Modify: `Brackets/AppConfig.swift:208-217` (the existing `extension Color`)

**Interfaces:**
- Produces: `AppTheme.Colors.lime950` (`Color`), `Color(hex: UInt32)` initializer.

- [ ] **Step 1: Add the `Color(hex:)` initializer**

In `Brackets/AppConfig.swift`, inside the existing `extension Color` (after `bracketsCardBackground`):

```swift
    /// Creates an opaque color from a 24-bit RGB hex value, e.g. `Color(hex: 0x6b7280)`.
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0
        )
    }
```

- [ ] **Step 2: Add `lime950`**

In `Brackets/AppTheme.swift`, immediately after the `lime900` declaration:

```swift
        /// `color/lime-950` — crestless fallback (second slot). Hex: #1a2e05
        static let lime950 = Color(red: 26/255, green: 46/255, blue: 5/255)
```

- [ ] **Step 3: Build to verify it compiles**

In Xcode: ⌘B. Expected: build succeeds.

- [ ] **Step 4: Commit**

```bash
git add Brackets/AppTheme.swift Brackets/AppConfig.swift
git commit -m "feat: add lime950 palette color and Color(hex:) initializer"
```

---

### Task 2: Create the unit test target

**Files:**
- Create: `BracketsTests/` group + target in `Brackets.xcodeproj`

This task is done in the Xcode UI because hand-editing `project.pbxproj` is error-prone.

- [ ] **Step 1: Add the test target**

In Xcode: File → New → Target → **Unit Testing Bundle**. Name it `BracketsTests`, language Swift, "Target to be Tested" = `Brackets`. Finish.

- [ ] **Step 2: Delete the auto-generated sample test file**

Remove the auto-created `BracketsTests.swift` sample (keep the target).

- [ ] **Step 3: Verify the empty target runs**

In Xcode: ⌘U. Expected: test run succeeds with 0 tests (no failures).

- [ ] **Step 4: Commit**

```bash
git add Brackets.xcodeproj BracketsTests
git commit -m "test: add BracketsTests unit test target"
```

---

### Task 3: `HSLColor` and dominant-color extraction

**Files:**
- Create: `Brackets/Final/TeamColorExtractor.swift`
- Test: `BracketsTests/TeamColorExtractorTests.swift`

**Interfaces:**
- Produces:
  - `struct HSLColor: Equatable { var hue: Double /*0..360*/; var saturation: Double /*0..1*/; var lightness: Double /*0..1*/; var color: Color; init(hue:saturation:lightness:) }`
  - `enum TeamColorExtractor { static func extractDominant(_ image: UIImage) -> HSLColor? }`
  - `func hueDistance(_ a: Double, _ b: Double) -> Double` (0..180, wraparound)

- [ ] **Step 1: Write the failing test**

`BracketsTests/TeamColorExtractorTests.swift`:

```swift
import XCTest
import UIKit
import SwiftUI
@testable import Brackets

final class TeamColorExtractorTests: XCTestCase {

    /// Draws a `side`×`side` image filled with `background`, with a centered
    /// square of `foreground` covering ~1/3 of the area.
    private func swatch(background: UIColor, foreground: UIColor?, side: CGFloat = 64) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        return renderer.image { ctx in
            background.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: side, height: side))
            if let fg = foreground {
                fg.setFill()
                let inset = side / 3
                ctx.fill(CGRect(x: inset, y: inset, width: side - 2*inset, height: side - 2*inset))
            }
        }
    }

    func test_mostlyBlackWithOrange_returnsLiftedOrangeHue() {
        let img = swatch(background: .black, foreground: UIColor(red: 0.85, green: 0.4, blue: 0.1, alpha: 1))
        let result = TeamColorExtractor.extractDominant(img)
        let hsl = try? XCTUnwrap(result)
        XCTAssertNotNil(hsl)
        // Orange sits roughly 20–45°.
        XCTAssertGreaterThan(hsl!.hue, 15)
        XCTAssertLessThan(hsl!.hue, 50)
        // Lift guarantees.
        XCTAssertGreaterThanOrEqual(hsl!.saturation, 0.55)
        XCTAssertGreaterThanOrEqual(hsl!.lightness, 0.42)
        XCTAssertLessThanOrEqual(hsl!.lightness, 0.62)
    }

    func test_allGray_returnsNil() {
        let img = swatch(background: UIColor(white: 0.5, alpha: 1), foreground: nil)
        XCTAssertNil(TeamColorExtractor.extractDominant(img))
    }

    func test_hueDistance_wrapsAround() {
        XCTAssertEqual(hueDistance(350, 10), 20, accuracy: 0.001)
        XCTAssertEqual(hueDistance(10, 350), 20, accuracy: 0.001)
        XCTAssertEqual(hueDistance(40, 90), 50, accuracy: 0.001)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

In Xcode: ⌘U. Expected: FAIL — `TeamColorExtractor`/`HSLColor` not defined.

- [ ] **Step 3: Write the implementation**

`Brackets/Final/TeamColorExtractor.swift`:

```swift
import SwiftUI
import UIKit
import CoreGraphics

/// A color in HSL, the space the card design reasons in. `hue` is 0..360,
/// `saturation` and `lightness` are 0..1.
struct HSLColor: Equatable {
    var hue: Double
    var saturation: Double
    var lightness: Double

    var color: Color {
        // Convert HSL -> RGB.
        let c = (1 - abs(2 * lightness - 1)) * saturation
        let hp = hue / 60
        let x = c * (1 - abs(hp.truncatingRemainder(dividingBy: 2) - 1))
        let (r1, g1, b1): (Double, Double, Double)
        switch hp {
        case 0..<1:  (r1, g1, b1) = (c, x, 0)
        case 1..<2:  (r1, g1, b1) = (x, c, 0)
        case 2..<3:  (r1, g1, b1) = (0, c, x)
        case 3..<4:  (r1, g1, b1) = (0, x, c)
        case 4..<5:  (r1, g1, b1) = (x, 0, c)
        default:     (r1, g1, b1) = (c, 0, x)
        }
        let m = lightness - c / 2
        return Color(red: r1 + m, green: g1 + m, blue: b1 + m)
    }
}

/// Shortest angular distance between two hues, 0..180.
func hueDistance(_ a: Double, _ b: Double) -> Double {
    let d = abs(a - b).truncatingRemainder(dividingBy: 360)
    return d > 180 ? 360 - d : d
}

enum TeamColorExtractor {

    /// Extracts a single dominant, lifted brand color from a logo, or nil if
    /// nothing survives the filters (e.g. an all-gray or all-black crest).
    static func extractDominant(_ image: UIImage, side: Int = 48) -> HSLColor? {
        guard let pixels = downscaledRGBA(image, side: side) else { return nil }

        var buckets: [Int: (count: Int, r: Double, g: Double, b: Double)] = [:]
        let count = side * side
        for i in 0..<count {
            let o = i * 4
            let r = Double(pixels[o]) / 255
            let g = Double(pixels[o + 1]) / 255
            let b = Double(pixels[o + 2]) / 255
            let a = Double(pixels[o + 3]) / 255
            if a < 200.0 / 255.0 { continue }

            let (h, s, l) = rgbToHSL(r, g, b)
            if l < 0.12 || l > 0.92 { continue }
            if s < 0.25 { continue }

            // Bucket by rounding each channel down to a multiple of 16.
            let key = (Int(r * 255) / 16) << 16 | (Int(g * 255) / 16) << 8 | (Int(b * 255) / 16)
            var entry = buckets[key] ?? (0, 0, 0, 0)
            entry.count += 1
            entry.r += r; entry.g += g; entry.b += b
            buckets[key] = entry
            _ = h
        }

        guard let best = buckets.values.max(by: { $0.count < $1.count }), best.count > 0 else {
            return nil
        }
        let n = Double(best.count)
        let (h, s, l) = rgbToHSL(best.r / n, best.g / n, best.b / n)

        // Lift into the usable band. Sampled colors only — callers must not
        // lift the fallback palette values.
        return HSLColor(
            hue: h,
            saturation: max(s, 0.55),
            lightness: min(max(l, 0.42), 0.62)
        )
    }

    /// Draws `image` into a `side`×`side` RGBA8 buffer and returns the raw bytes.
    private static func downscaledRGBA(_ image: UIImage, side: Int) -> [UInt8]? {
        guard let cg = image.cgImage else { return nil }
        let bytesPerPixel = 4
        let bytesPerRow = side * bytesPerPixel
        var data = [UInt8](repeating: 0, count: side * side * bytesPerPixel)
        let space = CGColorSpaceCreateDeviceRGB()
        let info = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let ctx = data.withUnsafeMutableBytes({ buf -> CGContext? in
            CGContext(
                data: buf.baseAddress,
                width: side, height: side,
                bitsPerComponent: 8, bytesPerRow: bytesPerRow,
                space: space, bitmapInfo: info
            )
        }) else { return nil }
        ctx.interpolationQuality = .low
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: side, height: side))
        return data
    }

    private static func rgbToHSL(_ r: Double, _ g: Double, _ b: Double) -> (Double, Double, Double) {
        let maxV = max(r, g, b), minV = min(r, g, b)
        let l = (maxV + minV) / 2
        guard maxV != minV else { return (0, 0, l) }
        let d = maxV - minV
        let s = l > 0.5 ? d / (2 - maxV - minV) : d / (maxV + minV)
        var h: Double
        switch maxV {
        case r: h = (g - b) / d + (g < b ? 6 : 0)
        case g: h = (b - r) / d + 2
        default: h = (r - g) / d + 4
        }
        h *= 60
        return (h, s, l)
    }
}
```

- [ ] **Step 4: Add the new file to the `Brackets` target**

In Xcode, confirm `TeamColorExtractor.swift` is a member of the `Brackets` target (and thus visible to `@testable import`).

- [ ] **Step 5: Run tests to verify they pass**

In Xcode: ⌘U. Expected: PASS (all three tests).

- [ ] **Step 6: Commit**

```bash
git add Brackets/Final/TeamColorExtractor.swift BracketsTests/TeamColorExtractorTests.swift
git commit -m "feat: add HSLColor and logo dominant-color extraction"
```

---

### Task 4: `resolveFinalPair` color-pair resolution

**Files:**
- Modify: `Brackets/Final/TeamColorExtractor.swift` (append)
- Test: `BracketsTests/FinalPairTests.swift`

**Interfaces:**
- Consumes: `HSLColor`, `hueDistance`, `Color(hex:)`.
- Produces: `func resolveFinalPair(a: HSLColor?, b: HSLColor?) -> (Color, Color)`

- [ ] **Step 1: Write the failing test**

`BracketsTests/FinalPairTests.swift`:

```swift
import XCTest
import SwiftUI
@testable import Brackets

final class FinalPairTests: XCTestCase {

    private func hsl(_ h: Double) -> HSLColor { HSLColor(hue: h, saturation: 0.6, lightness: 0.5) }

    func test_bothPresent_farHues_keepBoth() {
        let (a, b) = resolveFinalPair(a: hsl(20), b: hsl(210))
        XCTAssertEqual(a, hsl(20).color)
        XCTAssertEqual(b, hsl(210).color)
    }

    func test_bothPresent_closeHues_rotateSecond() {
        // 20° vs 30° are within 25°, so B rotates +40° to 70°.
        let (_, b) = resolveFinalPair(a: hsl(20), b: hsl(30))
        XCTAssertEqual(b, HSLColor(hue: 70, saturation: 0.6, lightness: 0.5).color)
    }

    func test_oneMissing_missingTakesFallbackZero_otherKeepsSample() {
        let (a1, b1) = resolveFinalPair(a: nil, b: hsl(200))
        XCTAssertEqual(a1, Color(hex: 0x6b7280))
        XCTAssertEqual(b1, hsl(200).color)

        let (a2, b2) = resolveFinalPair(a: hsl(200), b: nil)
        XCTAssertEqual(a2, hsl(200).color)
        XCTAssertEqual(b2, Color(hex: 0x6b7280))
    }

    func test_bothMissing_twoDistinctFallbacks_neverGrayTwice() {
        let (a, b) = resolveFinalPair(a: nil, b: nil)
        XCTAssertEqual(a, Color(hex: 0x6b7280))
        XCTAssertEqual(b, Color(hex: 0x1a2e05))
        XCTAssertNotEqual(a, b)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

In Xcode: ⌘U. Expected: FAIL — `resolveFinalPair` not defined.

- [ ] **Step 3: Write the implementation**

Append to `Brackets/Final/TeamColorExtractor.swift`:

```swift
/// Resolves the two colors a Final card paints with, applying the design's
/// separation and crestless-fallback rules. Fallback values are used as-is
/// (never lifted).
func resolveFinalPair(a: HSLColor?, b: HSLColor?) -> (Color, Color) {
    let fallback0 = Color(hex: 0x6b7280) // neutral gray
    let fallback1 = Color(hex: 0x1a2e05) // lime-950

    switch (a, b) {
    case let (a?, b?):
        var second = b
        if hueDistance(a.hue, b.hue) < 25 {
            second = HSLColor(
                hue: (b.hue + 40).truncatingRemainder(dividingBy: 360),
                saturation: b.saturation,
                lightness: b.lightness
            )
        }
        return (a.color, second.color)
    case let (a?, nil):
        return (a.color, fallback0)
    case let (nil, b?):
        return (fallback0, b.color)
    case (nil, nil):
        return (fallback0, fallback1)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

In Xcode: ⌘U. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Brackets/Final/TeamColorExtractor.swift BracketsTests/FinalPairTests.swift
git commit -m "feat: add resolveFinalPair color-pair resolution"
```

---

### Task 5: Countdown formatter

**Files:**
- Create: `Brackets/Final/FinalCountdown.swift`
- Test: `BracketsTests/FinalCountdownTests.swift`

**Interfaces:**
- Produces: `enum FinalCountdown { static func label(until date: Date?, isLiveOrFinished: Bool, now: Date, calendar: Calendar) -> String? }`
  - Returns `nil` when no pill should show; otherwise `"HOY"`, `"MAÑANA"`, or `"FALTAN N DÍAS"`.

- [ ] **Step 1: Write the failing test**

`BracketsTests/FinalCountdownTests.swift`:

```swift
import XCTest
@testable import Brackets

final class FinalCountdownTests: XCTestCase {

    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = AppConfig.DateTime.apiTimeZone
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        var comps = DateComponents()
        comps.year = y; comps.month = m; comps.day = d; comps.hour = h
        return cal.date(from: comps)!
    }

    func test_nilDate_returnsNil() {
        XCTAssertNil(FinalCountdown.label(until: nil, isLiveOrFinished: false, now: date(2026, 8, 8), calendar: cal))
    }

    func test_liveOrFinished_returnsNil() {
        XCTAssertNil(FinalCountdown.label(until: date(2026, 8, 13), isLiveOrFinished: true, now: date(2026, 8, 8), calendar: cal))
    }

    func test_pastDate_returnsNil() {
        XCTAssertNil(FinalCountdown.label(until: date(2026, 8, 1), isLiveOrFinished: false, now: date(2026, 8, 8), calendar: cal))
    }

    func test_sameDay_returnsHoy() {
        XCTAssertEqual(FinalCountdown.label(until: date(2026, 8, 8, 20), isLiveOrFinished: false, now: date(2026, 8, 8, 9), calendar: cal), "HOY")
    }

    func test_nextDay_returnsManana() {
        XCTAssertEqual(FinalCountdown.label(until: date(2026, 8, 9), isLiveOrFinished: false, now: date(2026, 8, 8), calendar: cal), "MAÑANA")
    }

    func test_fiveDays_returnsFaltan5Dias() {
        XCTAssertEqual(FinalCountdown.label(until: date(2026, 8, 13), isLiveOrFinished: false, now: date(2026, 8, 8), calendar: cal), "FALTAN 5 DÍAS")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

In Xcode: ⌘U. Expected: FAIL — `FinalCountdown` not defined.

- [ ] **Step 3: Write the implementation**

`Brackets/Final/FinalCountdown.swift`:

```swift
import Foundation

/// Produces the "FALTAN N DÍAS" style pill text for an upcoming final, or nil
/// when no countdown should show.
enum FinalCountdown {
    static func label(until date: Date?, isLiveOrFinished: Bool, now: Date, calendar: Calendar) -> String? {
        guard !isLiveOrFinished, let date else { return nil }
        let startOfToday = calendar.startOfDay(for: now)
        let startOfTarget = calendar.startOfDay(for: date)
        guard let days = calendar.dateComponents([.day], from: startOfToday, to: startOfTarget).day else { return nil }
        if days < 0 { return nil }
        if days == 0 { return "HOY" }
        if days == 1 { return "MAÑANA" }
        return "FALTAN \(days) DÍAS"
    }

    /// Convenience for views: uses the app timezone and the current date.
    static func label(until date: Date?, isLiveOrFinished: Bool) -> String? {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = AppConfig.DateTime.apiTimeZone
        return label(until: date, isLiveOrFinished: isLiveOrFinished, now: Date(), calendar: cal)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

In Xcode: ⌘U. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Brackets/Final/FinalCountdown.swift BracketsTests/FinalCountdownTests.swift
git commit -m "feat: add final countdown pill formatter"
```

---

### Task 6: `TeamColorStore` — cached async color resolution

**Files:**
- Create: `Brackets/Final/TeamColorStore.swift`

**Interfaces:**
- Consumes: `HSLColor`, `TeamColorExtractor.extractDominant`.
- Produces:
  - `@MainActor @Observable final class TeamColorStore { static let shared: TeamColorStore; func color(forTeamId id: Int?, logoURL: String?) async -> HSLColor? }`

This task has no unit test (it performs network I/O and is a thin cache over the already-tested extractor). It is verified by the view previews in later tasks.

- [ ] **Step 1: Write the implementation**

`Brackets/Final/TeamColorStore.swift`:

```swift
import SwiftUI
import UIKit

/// Downloads a team's logo once, extracts its dominant color, and memoizes the
/// result for the process lifetime. Never re-samples per render.
@MainActor
@Observable
final class TeamColorStore {
    static let shared = TeamColorStore()

    private var cache: [Int: HSLColor?] = [:]
    private var inflight: [Int: Task<HSLColor?, Never>] = [:]

    /// Returns the extracted color for a team, or nil if there is no logo or
    /// nothing survives extraction. Concurrent calls for the same id coalesce.
    func color(forTeamId id: Int?, logoURL: String?) async -> HSLColor? {
        guard let id else { return nil }
        if let cached = cache[id] { return cached }
        if let task = inflight[id] { return await task.value }

        let task = Task<HSLColor?, Never> { [logoURL] in
            guard let logoURL, let url = URL(string: logoURL) else { return nil }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let image = UIImage(data: data) else { return nil }
                return TeamColorExtractor.extractDominant(image)
            } catch {
                return nil
            }
        }
        inflight[id] = task
        let result = await task.value
        cache[id] = result
        inflight[id] = nil
        return result
    }
}
```

- [ ] **Step 2: Add the file to the `Brackets` target and build**

In Xcode: confirm target membership, then ⌘B. Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
git add Brackets/Final/TeamColorStore.swift
git commit -m "feat: add cached TeamColorStore for logo color resolution"
```

---

### Task 7: `FinalCardBackground` — the four-layer animated background

**Files:**
- Create: `Brackets/Final/FinalCardBackground.swift`

**Interfaces:**
- Produces: `struct FinalCardBackground: View { init(colorA: Color, colorB: Color, cornerRadius: CGFloat = 16) }`

Verified visually via `#Preview`; no unit test (pure view).

- [ ] **Step 1: Write the implementation**

`Brackets/Final/FinalCardBackground.swift`:

```swift
import SwiftUI

/// The four-layer animated card background: dark base, static team split,
/// three screen-blended moving blobs, and a scrim. Honors reduced motion and
/// stops animating when off-screen or backgrounded.
struct FinalCardBackground: View {
    let colorA: Color
    let colorB: Color
    var cornerRadius: CGFloat = 16

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var animate = false

    private var motionEnabled: Bool { !reduceMotion && scenePhase == .active && animate }

    var body: some View {
        ZStack {
            // Layers 1–3 composite together so `.screen` adds light onto the base.
            ZStack {
                base                      // layer 1
                staticSplit               // layer 2
                if !reduceMotion {        // layer 3 (skipped under reduced motion)
                    blobs
                }
            }
            .compositingGroup()

            scrim                          // layer 4
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .onAppear { animate = true }
        .onDisappear { animate = false }
    }

    // Layer 1 — near-black radial base.
    private var base: some View {
        RadialGradient(
            colors: [Color(white: 0.10), Color(white: 0.02)],
            center: .center, startRadius: 0, endRadius: 420
        )
    }

    // Layer 2 — static diagonal split, ~100°, 26% alpha per edge.
    private var staticSplit: some View {
        LinearGradient(
            stops: [
                .init(color: colorA.opacity(0.26), location: 0.0),
                .init(color: .clear, location: 0.5),
                .init(color: colorB.opacity(0.26), location: 1.0),
            ],
            startPoint: UnitPoint(x: -0.02, y: 0.15),   // ~100° diagonal
            endPoint: UnitPoint(x: 1.02, y: 0.85)
        )
    }

    // Layer 3 — three screen-blended blobs.
    private var blobs: some View {
        ZStack {
            blob(color: colorA, anchor: .leading,  duration: 7.0,  phase: 0)
            blob(color: colorB, anchor: .trailing, duration: 9.45, phase: 1)
            blob(color: blend(colorA, colorB), anchor: .center, duration: 4.9, phase: 2)
        }
        .blendMode(.screen)
    }

    private func blob(color: Color, anchor: UnitPoint, duration: Double, phase: Int) -> some View {
        let on = motionEnabled
        // Each blob rests off its own edge and drifts within ±95x / ±120y.
        let baseX: CGFloat = anchor == .leading ? -120 : anchor == .trailing ? 120 : 0
        let dx: CGFloat = on ? (anchor == .trailing ? -95 : 95) : 0
        let dy: CGFloat = on ? (phase == 1 ? 120 : -120) : 0
        return RadialGradient(
            colors: [color, .clear],
            center: .center, startRadius: 0, endRadius: 200
        )
        .frame(width: 330, height: 400)
        .blur(radius: 44)
        .scaleEffect(on ? 1.35 : 1.0)
        .opacity(on ? 1.0 : 0.5)
        .offset(x: baseX + dx, y: dy)
        .animation(
            on ? .easeInOut(duration: duration).repeatForever(autoreverses: true) : .default,
            value: on
        )
    }

    // Layer 4 — vertical scrim + vignette to guarantee text contrast.
    private var scrim: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black.opacity(0.55), Color.black.opacity(0.15), Color.black.opacity(0.55)],
                startPoint: .top, endPoint: .bottom
            )
            RadialGradient(
                colors: [.clear, Color.black.opacity(0.45)],
                center: .center, startRadius: 120, endRadius: 480
            )
        }
    }

    private func blend(_ a: Color, _ b: Color) -> Color {
        let ua = UIColor(a), ub = UIColor(b)
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        ua.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        ub.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return Color(red: Double((r1 + r2) / 2), green: Double((g1 + g2) / 2), blue: Double((b1 + b2) / 2))
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        FinalCardBackground(colorA: Color(hex: 0xE06A1A), colorB: Color(hex: 0x8B3A62))
            .frame(width: 360, height: 620)
    }
}
```

- [ ] **Step 2: Verify the preview renders**

In Xcode: open the file, run the `#Preview`. Expected: a dark rounded card with an orange→magenta split and soft moving blobs (motion visible in a live preview). Toggle Xcode's Environment Overrides → Reduce Motion and confirm blobs disappear but the split/scrim remain.

- [ ] **Step 3: Commit**

```bash
git add Brackets/Final/FinalCardBackground.swift
git commit -m "feat: add four-layer animated final card background"
```

---

### Task 8: `FinalMatchCard` — the card content

**Files:**
- Create: `Brackets/Final/FinalMatchCard.swift`

**Interfaces:**
- Consumes: `BracketMatchup` (existing), `Team` (existing), `Venue` (existing), `FinalCardBackground`, `FinalCountdown`, `AppTheme`.
- Produces:
  - `enum FinalCardSize { case prominent, compact }`
  - `struct FinalMatchCard: View { init(matchup: BracketMatchup, stageLabel: String, size: FinalCardSize, colorA: Color, colorB: Color, tournament: Tournament) }`

Notes on data already available on `BracketMatchup` (defined in `BracketView.swift`): `homeTeam/awayTeam: Team?`, `homeScore/awayScore: Int?`, `homeIsWinner/awayIsWinner: Bool`, `hasGame: Bool`, `game: Game?`, `homePlaceholder/awayPlaceholder: String?`, `scheduledTime: Date?`, `venue: Venue?`. Reuse `Team.name`, `Team.fullImageURL`.

- [ ] **Step 1: Write the implementation**

`Brackets/Final/FinalMatchCard.swift`:

```swift
import SwiftUI

enum FinalCardSize {
    case prominent
    case compact

    var crestDiameter: CGFloat { self == .prominent ? 132 : 84 }
    var timeSize: CGFloat { self == .prominent ? 60 : 34 }
    var dateSize: CGFloat { self == .prominent ? 15 : 12 }
    var nameSize: CGFloat { self == .prominent ? 20 : 15 }
    var showsCountdown: Bool { self == .prominent }
    var verticalPadding: CGFloat { self == .prominent ? 28 : 18 }
}

/// One Final (or Tercer Lugar) card: animated background + crest row + result
/// region + optional countdown + venue footer. Tappable when a real game backs it.
struct FinalMatchCard: View {
    let matchup: BracketMatchup
    let stageLabel: String
    let size: FinalCardSize
    let colorA: Color
    let colorB: Color
    let tournament: Tournament

    @Environment(\.openURL) private var openURL

    private var isLive: Bool { matchup.game?.isLive ?? false }
    private var isFinished: Bool { matchup.game?.isFinished ?? false }
    private var decided: Bool { matchup.homeIsWinner || matchup.awayIsWinner }

    var body: some View {
        let content = card
        if let game = matchup.game {
            NavigationLink {
                destination(for: game)
            } label: { content }
            .buttonStyle(.plain)
        } else {
            content
        }
    }

    @ViewBuilder
    private func destination(for game: Game) -> some View {
        if game.isLive {
            LiveGameDetailView(game: game, tournamentId: tournament.id, tournamentName: tournament.name)
        } else if game.isFinished {
            GameResultView(game: game, tournamentId: tournament.id, tournamentName: tournament.name, gender: tournament.gender)
        } else {
            UpcomingGameView(game: game, tournamentId: tournament.id, gender: tournament.gender)
        }
    }

    private var card: some View {
        VStack(spacing: size == .prominent ? 22 : 12) {
            stagePill
            crestRow
            resultRegion
            if size.showsCountdown, let text = FinalCountdown.label(until: matchup.scheduledTime, isLiveOrFinished: isLive || isFinished) {
                countdownPill(text)
            }
            Spacer(minLength: 0)
            if let venue = matchup.venue {
                divider
                venueFooter(venue)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, size.verticalPadding)
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, maxHeight: size == .prominent ? .infinity : nil)
        .background(FinalCardBackground(colorA: colorA, colorB: colorB))
        .overlay(alignment: .top) {
            if isLive { BracketLiveBadge().offset(y: -9) }
        }
    }

    private var stagePill: some View {
        Text(stageLabel.uppercased())
            .font(AppTheme.Typography.condensed(.semibold, size: 14))
            .tracking(1)
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1))
    }

    private var crestRow: some View {
        HStack(alignment: .top, spacing: 12) {
            teamColumn(team: matchup.homeTeam, placeholder: matchup.homePlaceholder, isWinner: matchup.homeIsWinner)
            VStack {
                Text("VS")
                    .font(AppTheme.Typography.condensed(.bold, size: size == .prominent ? 22 : 16))
                    .foregroundStyle(.white)
                    .frame(height: size.crestDiameter)
            }
            teamColumn(team: matchup.awayTeam, placeholder: matchup.awayPlaceholder, isWinner: matchup.awayIsWinner)
        }
    }

    private func teamColumn(team: Team?, placeholder: String?, isWinner: Bool) -> some View {
        let name = team?.name ?? placeholder ?? "TBD"
        return VStack(spacing: 10) {
            crest(team: team, name: name)
            Text(name.uppercased())
                .font(AppTheme.Typography.condensed(isWinner ? .bold : .semibold, size: size.nameSize))
                .foregroundStyle(isWinner || !decided ? .white : Color.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func crest(team: Team?, name: String) -> some View {
        let d = size.crestDiameter
        let gray700 = Color(white: 0.28)
        if let urlString = team?.fullImageURL, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image): image.resizable().scaledToFit()
                default: initialChip(name: name, diameter: d, fill: gray700)
                }
            }
            .frame(width: d, height: d)
            .clipShape(Circle())
            .overlay(Circle().stroke(gray700, lineWidth: 1))
        } else {
            initialChip(name: name, diameter: d, fill: gray700)
        }
    }

    private func initialChip(name: String, diameter: CGFloat, fill: Color) -> some View {
        Circle()
            .fill(fill)
            .frame(width: diameter, height: diameter)
            .overlay(
                Text(String(name.first.map(String.init) ?? "?").uppercased())
                    .font(AppTheme.Typography.condensed(.bold, size: diameter * 0.46))
                    .foregroundStyle(.white)
            )
            .overlay(Circle().stroke(Color(white: 0.28), lineWidth: 1))
    }

    @ViewBuilder
    private var resultRegion: some View {
        if isLive || isFinished {
            HStack(spacing: 18) {
                scoreText(matchup.homeScore, isWinner: matchup.homeIsWinner)
                Text("-").font(AppTheme.Typography.condensed(.bold, size: size.timeSize)).foregroundStyle(.white.opacity(0.5))
                scoreText(matchup.awayScore, isWinner: matchup.awayIsWinner)
            }
        } else {
            VStack(spacing: 4) {
                if let time = matchup.scheduledTime {
                    Text(Self.dateFormatter.string(from: time).uppercased())
                        .font(AppTheme.Typography.condensed(.medium, size: size.dateSize))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.8))
                    Text(Self.timeFormatter.string(from: time))
                        .font(AppTheme.Typography.condensed(.bold, size: size.timeSize))
                        .foregroundStyle(.white)
                }
            }
        }
    }

    private func scoreText(_ score: Int?, isWinner: Bool) -> some View {
        Text(score.map(String.init) ?? "-")
            .font(AppTheme.Typography.condensed(.bold, size: size.timeSize))
            .foregroundStyle(isWinner ? AppTheme.Colors.accent : .white)
    }

    private func countdownPill(_ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "clock").font(.system(size: 11))
            Text(text).font(AppTheme.Typography.condensed(.semibold, size: 13)).tracking(1)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14).padding(.vertical, 7)
        .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1))
    }

    private var divider: some View {
        Rectangle().fill(Color.white.opacity(0.15)).frame(height: 1).padding(.horizontal, 8)
    }

    @ViewBuilder
    private func venueFooter(_ venue: Venue) -> some View {
        let row = HStack(spacing: 5) {
            Image(systemName: "mappin.and.ellipse").font(.system(size: 12))
            Text(venue.name).font(AppTheme.Typography.condensed(.medium, size: 15))
        }
        .foregroundStyle(.white.opacity(0.85))

        if let mapsURL = venue.googleMapsURL {
            Button { openURL(mapsURL) } label: { row }.buttonStyle(.plain)
        } else {
            row
        }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_MX")
        f.timeZone = AppConfig.DateTime.apiTimeZone
        f.dateFormat = "d MMMM, yyyy"
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_MX")
        f.timeZone = AppConfig.DateTime.apiTimeZone
        f.dateFormat = "h:mm a"
        f.amSymbol = "AM"; f.pmSymbol = "PM"
        return f
    }()
}
```

- [ ] **Step 2: Confirm `Venue.googleMapsURL` and `BracketLiveBadge` exist**

Grep to verify the names used compile:

Run: `grep -rn "googleMapsURL\|struct BracketLiveBadge" Brackets/*.swift`
Expected: both are found (used already by `BracketView`). If `BracketLiveBadge` is `private` to `BracketView`, move it to file scope in `BracketView.swift` (remove `private`) so this card can reuse it.

- [ ] **Step 3: Build**

In Xcode: ⌘B. Expected: build succeeds.

- [ ] **Step 4: Commit**

```bash
git add Brackets/Final/FinalMatchCard.swift Brackets/BracketView.swift
git commit -m "feat: add FinalMatchCard content view"
```

---

### Task 9: `FinalBracketView` — layout decision + color wiring

**Files:**
- Create: `Brackets/Final/FinalBracketView.swift`

**Interfaces:**
- Consumes: `BracketMatchup`, `Tournament`, `FinalMatchCard`, `TeamColorStore`, `HSLColor`, `resolveFinalPair`.
- Produces: `struct FinalBracketView: View { init(finalMatchup: BracketMatchup, thirdMatchup: BracketMatchup, tournament: Tournament) }`
- Also produces a helper the caller uses: `func finalMatchupHasInfo(_ m: BracketMatchup) -> Bool` (file-scope in this file).

- [ ] **Step 1: Write the implementation**

`Brackets/Final/FinalBracketView.swift`:

```swift
import SwiftUI

/// True when a matchup carries any information — a real game, or a placeholder
/// that contributed a team name, a time, or a venue.
func finalMatchupHasInfo(_ m: BracketMatchup) -> Bool {
    m.hasGame || m.homePlaceholder != nil || m.awayPlaceholder != nil || m.scheduledTime != nil || m.venue != nil
}

/// Full-screen layout for the `final` bracket type. Shows the Final card always
/// (TBD when it has no info) and the Tercer Lugar card only when it has info.
struct FinalBracketView: View {
    let finalMatchup: BracketMatchup
    let thirdMatchup: BracketMatchup
    let tournament: Tournament

    @State private var finalA: HSLColor?
    @State private var finalB: HSLColor?
    @State private var thirdA: HSLColor?
    @State private var thirdB: HSLColor?

    private var showsThird: Bool { finalMatchupHasInfo(thirdMatchup) }

    var body: some View {
        Group {
            if showsThird {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 16) {
                        finalCard(size: .compact)
                        thirdCard(size: .compact)
                    }
                    .padding(.horizontal, AppTheme.Layout.screenPadding)
                    .padding(.bottom, 24)
                }
            } else {
                finalCard(size: .prominent)
                    .padding(.horizontal, AppTheme.Layout.screenPadding)
                    .padding(.bottom, 24)
            }
        }
        .task { await resolveColors() }
    }

    private func finalCard(size: FinalCardSize) -> some View {
        let pair = resolveFinalPair(a: finalA, b: finalB)
        return FinalMatchCard(
            matchup: finalMatchup, stageLabel: "FINAL", size: size,
            colorA: pair.0, colorB: pair.1, tournament: tournament
        )
        .animation(.easeInOut(duration: 0.4), value: finalA)
        .animation(.easeInOut(duration: 0.4), value: finalB)
    }

    private func thirdCard(size: FinalCardSize) -> some View {
        let pair = resolveFinalPair(a: thirdA, b: thirdB)
        return FinalMatchCard(
            matchup: thirdMatchup, stageLabel: "TERCER LUGAR", size: size,
            colorA: pair.0, colorB: pair.1, tournament: tournament
        )
        .animation(.easeInOut(duration: 0.4), value: thirdA)
        .animation(.easeInOut(duration: 0.4), value: thirdB)
    }

    private func resolveColors() async {
        let store = TeamColorStore.shared
        async let fa = store.color(forTeamId: finalMatchup.homeTeam?.id, logoURL: finalMatchup.homeTeam?.fullImageURL)
        async let fb = store.color(forTeamId: finalMatchup.awayTeam?.id, logoURL: finalMatchup.awayTeam?.fullImageURL)
        finalA = await fa
        finalB = await fb
        if showsThird {
            async let ta = store.color(forTeamId: thirdMatchup.homeTeam?.id, logoURL: thirdMatchup.homeTeam?.fullImageURL)
            async let tb = store.color(forTeamId: thirdMatchup.awayTeam?.id, logoURL: thirdMatchup.awayTeam?.fullImageURL)
            thirdA = await ta
            thirdB = await tb
        }
    }
}
```

- [ ] **Step 2: Ensure `HSLColor` is `Equatable`**

`.animation(value:)` requires `Equatable`; `HSLColor` already conforms (Task 3). No action if so.

- [ ] **Step 3: Build**

In Xcode: ⌘B. Expected: build succeeds.

- [ ] **Step 4: Commit**

```bash
git add Brackets/Final/FinalBracketView.swift
git commit -m "feat: add FinalBracketView layout and color wiring"
```

---

### Task 10: Branch `BracketView` to the new view for `type == "final"`

**Files:**
- Modify: `Brackets/BracketView.swift` (view body around lines 59–74; add a matchup builder)

**Interfaces:**
- Consumes: `FinalBracketView`, existing `buildMatchup(stage:slot:propagation:)`, `activeType`, `selectedBracket`.

- [ ] **Step 1: Add final-matchup builders on `BracketView`**

In `Brackets/BracketView.swift`, add near `buildRounds()`:

```swift
    private func finalTypeFinalMatchup() -> BracketMatchup {
        buildMatchup(stage: "Final", slot: 1, propagation: nil)
    }

    private func finalTypeThirdMatchup() -> BracketMatchup {
        buildMatchup(stage: "Tercer Lugar", slot: 1, propagation: nil)
    }
```

- [ ] **Step 2: Branch the content area**

In the `ZStack` in `body`, replace the `else { bracketContent() }` branch so the `final` type renders the new view. The block currently reads:

```swift
            } else {
                bracketContent()
            }
```

Change it to:

```swift
            } else if activeType == "final" {
                FinalBracketView(
                    finalMatchup: finalTypeFinalMatchup(),
                    thirdMatchup: finalTypeThirdMatchup(),
                    tournament: tournament
                )
            } else {
                bracketContent()
            }
```

Note: the empty-state guard above (`games.isEmpty && brackets.allSatisfy { ... }`) still applies. For a `final` bracket whose placeholders exist, `brackets` is non-empty with placeholders, so the guard is false and this branch is reached. If a `final` bracket has genuinely no games and no placeholders, the empty state shows — which is correct.

- [ ] **Step 3: Build**

In Xcode: ⌘B. Expected: build succeeds.

- [ ] **Step 4: Manual verification against the demo data**

Point the app at a `final`-type bracket (e.g. tournament 76 with the Playoffs/Final bracket, or the demo `https://demo.getbrackets.app`). Verify:
- With both Final and Tercer Lugar placeholders → two compact cards (mockup 1).
- With only Final info → one prominent card + countdown (mockup 3).
- With no info → one prominent TBD card (mockup 4).
- Crestless teams → initial chips + quieter fallback colors (mockup 2).
- Reduce Motion on → blobs gone, split/scrim remain.

- [ ] **Step 5: Commit**

```bash
git add Brackets/BracketView.swift
git commit -m "feat: render FinalBracketView for the final bracket type"
```

---

## Self-Review

**Spec coverage:**
- §3.1 branch point → Task 10. §3.2 matchup construction → Task 10 (builders) reusing existing `buildMatchup`. §3.3 has-info rule → Task 9 (`finalMatchupHasInfo`). §4 layout decision → Task 9. §5.1 `FinalBracketView` → Task 9. §5.2 `FinalMatchCard` → Task 8. §5.3 background → Task 7. §5.4 countdown → Task 5. §6 four layers + reduced motion + off-screen + scrim → Task 7. §7 color pipeline (extract/store/pair/crossfade) → Tasks 3, 4, 6, 9. §8 `lime950` → Task 1. §9 files → all tasks. §10 testing → Tasks 2–5. All spec sections map to a task.
- `Color(hex:)` is needed by the fallback pair (Task 4) and previews; added in Task 1 before first use.

**Placeholder scan:** No TBD/TODO/"handle edge cases"/"similar to" placeholders; all code steps contain full code.

**Type consistency:** `HSLColor` (hue/saturation/lightness, `.color`, `Equatable`) used consistently in Tasks 3, 4, 6, 9. `extractDominant(_:side:)` (Task 3) called by `TeamColorStore` (Task 6). `resolveFinalPair(a:b:) -> (Color, Color)` (Task 4) called in Task 9. `FinalCountdown.label(until:isLiveOrFinished:)` (Task 5) called in Task 8. `FinalCardSize` / `FinalMatchCard(matchup:stageLabel:size:colorA:colorB:tournament:)` (Task 8) called in Task 9. `FinalBracketView(finalMatchup:thirdMatchup:tournament:)` (Task 9) called in Task 10. Detail-view initializers match the existing `BracketView` call sites.
