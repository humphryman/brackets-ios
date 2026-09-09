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
