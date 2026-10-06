import XCTest
@testable import AeroCheatCore

final class SuggestionPolicyTests: XCTestCase {
    private final class Clock {
        var now = Date(timeIntervalSince1970: 1_800_000_000)   // mid-morning UTC
        func advance(_ seconds: TimeInterval) { now.addTimeInterval(seconds) }
    }

    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    private func suggestion(_ workspace: String) throws -> Suggestion {
        let modes = try AeroSpaceConfig.parse("""
        [mode.main.binding]
        ctrl-alt-1 = 'workspace 1'
        ctrl-alt-2 = 'workspace 2'
        ctrl-alt-3 = 'workspace 3'
        """)
        return try XCTUnwrap(ActionResolver(modes: modes).suggestion(for: MouseSwitch(from: "9", to: workspace)))
    }

    private func makePolicy(_ clock: Clock) -> SuggestionPolicy {
        SuggestionPolicy(calendar: calendar, clock: { clock.now })
    }

    func testFirstSuggestionIsShown() throws {
        let clock = Clock()
        var policy = makePolicy(clock)
        XCTAssertEqual(policy.consider(try suggestion("1")), .show)
    }

    func testSameSuggestionHasA30SecondCooldown() throws {
        let clock = Clock()
        var policy = makePolicy(clock)
        let s = try suggestion("1")
        XCTAssertEqual(policy.consider(s), .show)
        clock.advance(10)
        XCTAssertEqual(policy.consider(s), .suppressed(.cooldown))
        clock.advance(20.5)
        XCTAssertEqual(policy.consider(s), .show)
    }

    func testAtMostOneToastEveryFiveSeconds() throws {
        let clock = Clock()
        var policy = makePolicy(clock)
        XCTAssertEqual(policy.consider(try suggestion("1")), .show)
        clock.advance(4)
        XCTAssertEqual(policy.consider(try suggestion("2")), .suppressed(.rateLimited))
        clock.advance(1.5)
        XCTAssertEqual(policy.consider(try suggestion("2")), .show)
    }

    func testPressingTheBindingMutesItForTheDay() throws {
        let clock = Clock()
        var policy = makePolicy(clock)
        let s = try suggestion("3")
        XCTAssertEqual(policy.consider(s), .show)
        clock.advance(10)
        policy.recordKeyboard(binding: "ctrl-alt-3")
        clock.advance(600)
        XCTAssertEqual(policy.consider(s), .suppressed(.mutedToday))
        clock.advance(24 * 3600)
        XCTAssertEqual(policy.consider(s), .show)
    }

    func testPressingABindingThatWasNeverSuggestedChangesNothing() throws {
        let clock = Clock()
        var policy = makePolicy(clock)
        policy.recordKeyboard(binding: "ctrl-alt-3")
        XCTAssertEqual(policy.consider(try suggestion("3")), .show)
    }

    func testModifierOrderDoesNotMatterWhenLearning() throws {
        let clock = Clock()
        var policy = makePolicy(clock)
        let s = try suggestion("3")
        XCTAssertEqual(policy.consider(s), .show)
        policy.recordKeyboard(binding: "alt-ctrl-3")
        clock.advance(60)
        XCTAssertEqual(policy.consider(s), .suppressed(.mutedToday))
    }

    func testBacksOffAfterThreeIgnoredSuggestions() throws {
        let clock = Clock()
        var policy = makePolicy(clock)
        let s = try suggestion("2")
        for _ in 0..<3 {
            XCTAssertEqual(policy.consider(s), .show)
            clock.advance(61)   // not followed up within the 60 s window
        }
        XCTAssertEqual(policy.consider(s), .suppressed(.mutedToday))
        clock.advance(24 * 3600)
        XCTAssertEqual(policy.consider(s), .show)
    }

    func testFollowUpResetsTheIgnoredCount() throws {
        let clock = Clock()
        var policy = makePolicy(clock)
        let s = try suggestion("2")
        for _ in 0..<2 {
            XCTAssertEqual(policy.consider(s), .show)
            clock.advance(61)
        }
        XCTAssertEqual(policy.consider(s), .show)
        policy.recordKeyboard(binding: "ctrl-alt-2")
        clock.advance(24 * 3600)
        for _ in 0..<2 {
            XCTAssertEqual(policy.consider(s), .show)
            clock.advance(61)
        }
        XCTAssertEqual(policy.consider(s), .show)   // third unanswered: counter restarted, not yet backed off
    }

    func testSnoozeSuppressesUntilItExpires() throws {
        let clock = Clock()
        var policy = makePolicy(clock)
        policy.snooze(for: 3600)
        XCTAssertTrue(policy.isSnoozed)
        clock.advance(1800)
        XCTAssertEqual(policy.consider(try suggestion("1")), .suppressed(.snoozed))
        clock.advance(1801)
        XCTAssertFalse(policy.isSnoozed)
        XCTAssertEqual(policy.consider(try suggestion("1")), .show)
    }

    func testResumeEndsTheSnooze() throws {
        let clock = Clock()
        var policy = makePolicy(clock)
        policy.snooze()
        policy.resume()
        XCTAssertEqual(policy.consider(try suggestion("1")), .show)
    }
}
