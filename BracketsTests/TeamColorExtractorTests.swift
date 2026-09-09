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
