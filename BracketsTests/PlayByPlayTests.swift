import XCTest
@testable import Brackets

final class PlayByPlayTests: XCTestCase {

    /// Builds a PlayByPlayEvent from the raw API shape (it only has a JSON decoder).
    private func event(
        _ id: Int, _ stat: String, _ period: String,
        a: Int, b: Int, team: Int, number: Int? = nil, last: String = "L"
    ) -> PlayByPlayEvent {
        var dict: [String: Any] = [
            "id": id, "stat_name": stat, "period": period,
            "score_a": a, "score_b": b,
            "team_name": team == 200 ? "Beta" : "Alpha",
            "team_stat_id": team, "player_first": "F", "player_last": last
        ]
        if let number { dict["player_number"] = number }
        let data = try! JSONSerialization.data(withJSONObject: dict)
        return try! JSONDecoder().decode(PlayByPlayEvent.self, from: data)
    }

    /// Newest-first feed. Team 200 (Beta) drives score_b and is passed as teams[0], so
    /// the "left" column is side B — the reversed-order case that broke naive indexing.
    private func makeFeed() -> [PlayByPlayEvent] {
        [
            event(9, "xyz", "2P", a: 3, b: 5, team: 200, number: 9),          // unknown stat
            event(8, "ftm", "2P", a: 3, b: 5, team: 100, number: 10),         // Alpha FT (side A)
            event(7, "pfs", "2P", a: 2, b: 5, team: 200, number: 7, last: "Siete"), // Beta #7 foul #2
            event(6, "sale", "1P", a: 2, b: 5, team: 100, number: 10),
            event(5, "pfs", "1P", a: 2, b: 5, team: 200, number: 7, last: "Siete"), // Beta #7 foul #1
            event(4, "three_pm", "1P", a: 2, b: 5, team: 200, number: 7),     // Beta scores (side B)
            event(3, "two_pm", "1P", a: 2, b: 2, team: 100, number: 10),      // Alpha scores (side A)
            event(2, "two_pm", "1P", a: 0, b: 2, team: 200, number: 7),       // Beta first basket
            event(1, "entra", "1P", a: 0, b: 0, team: 100, number: 11)
        ]
    }

    private func build() -> [PlayByPlayPeriod] {
        PlayByPlayBuilder.build(
            events: makeFeed(),
            teams: [PlayByPlayTeam(id: 200, score: 5), PlayByPlayTeam(id: 100, score: 3)],
            longNameStats: ["xyz": "Algo Raro"]
        )
    }

    private func row(_ id: Int) -> PlayByPlayRow? {
        build().flatMap { $0.rows }.first { $0.id == id }
    }

    // MARK: Period grouping

    func test_groupsByPeriod_inFeedOrder() {
        let periods = build()
        XCTAssertEqual(periods.map { $0.id }, ["2P", "1P"])
        XCTAssertEqual(periods.map { $0.title }, ["PERIODO 2", "PERIODO 1"])
        XCTAssertEqual(periods[0].rows.count, 3)
        XCTAssertEqual(periods[1].rows.count, 6)
    }

    // MARK: Score orientation (left = teams[0], regardless of score_a/score_b order)

    func test_leftTeamScoringEmphasizesLeft() {
        // Beta (teams[0]) drives score_b, so its basket lands on the left column.
        XCTAssertEqual(row(2)?.emphasis, .left)
        XCTAssertEqual(row(2)?.leftScore, 2)   // score_b
        XCTAssertEqual(row(2)?.rightScore, 0)  // score_a
    }

    func test_rightTeamScoringEmphasizesRight() {
        XCTAssertEqual(row(3)?.emphasis, .right)
        XCTAssertEqual(row(3)?.leftScore, 2)   // score_b
        XCTAssertEqual(row(3)?.rightScore, 2)  // score_a
    }

    func test_nonScoringRowHidesScore() {
        XCTAssertEqual(row(6)?.emphasis, PlayByPlayEmphasis.none)
        XCTAssertEqual(row(6)?.showsScore, false)
    }

    // MARK: Labels + kinds

    func test_actionLabelsAndKinds() {
        XCTAssertEqual(row(3)?.actionLabel, "2 puntos")
        XCTAssertEqual(row(3)?.actionKind, .scoring)
        XCTAssertEqual(row(4)?.actionLabel, "3 puntos")
        XCTAssertEqual(row(8)?.actionLabel, "Tiro libre")
        XCTAssertEqual(row(6)?.actionLabel, "Sale")
        XCTAssertEqual(row(6)?.actionKind, .salePerdida)
        XCTAssertEqual(row(1)?.actionLabel, "Entra")
        XCTAssertEqual(row(1)?.actionKind, .entra)
    }

    func test_unknownStatFallsBackToLongName() {
        XCTAssertEqual(row(9)?.actionLabel, "Algo Raro")
        XCTAssertEqual(row(9)?.actionKind, .neutral)
    }

    // MARK: Running foul tally

    func test_runningFoulCountPerPlayer_acrossPeriods() {
        XCTAssertEqual(row(5)?.actionLabel, "Falta personal (1)")
        XCTAssertEqual(row(7)?.actionLabel, "Falta personal (2)")
    }

    // MARK: Side inference fallbacks

    func test_sideInference_fallsBackToFinalScore_whenNoBaskets() {
        // Only substitutions — no increments to infer from; final scores disambiguate.
        let subsOnly = [
            event(2, "sale", "1P", a: 4, b: 9, team: 100, number: 10),
            event(1, "entra", "1P", a: 0, b: 0, team: 200, number: 7)
        ]
        let map = PlayByPlayBuilder.sideByTeam(
            events: subsOnly,
            teams: [PlayByPlayTeam(id: 100, score: 4), PlayByPlayTeam(id: 200, score: 9)]
        )
        XCTAssertEqual(map[100], .a) // score 4 == final score_a
        XCTAssertEqual(map[200], .b) // score 9 == final score_b
    }
}
