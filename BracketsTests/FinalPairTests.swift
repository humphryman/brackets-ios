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
