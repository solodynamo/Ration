import XCTest
@testable import Ration

final class BudgetCalibratorTests: XCTestCase {
    private func sample(minutesAgo: Double, tokens: Int, now: Date) -> UsageSample {
        UsageSample(
            id: UUID(),
            provider: .claudeCode,
            timestamp: now.addingTimeInterval(-minutesAgo * 60),
            project: "repo",
            gitBranch: nil,
            sessionId: "s1",
            inputTokens: tokens,
            outputTokens: 0,
            cacheWriteTokens: 0,
            cacheReadTokens: 0
        )
    }

    func testNoSamplesReturnsNil() {
        XCTAssertNil(BudgetCalibrator.suggestBudget(from: []))
    }

    func testPadsAndRoundsTheBusiestWindow() {
        let now = Date()
        // 1,000,000 tokens packed inside one 5h window, 8 days ago.
        let samples = [
            sample(minutesAgo: 8 * 24 * 60, tokens: 600_000, now: now),
            sample(minutesAgo: 8 * 24 * 60 - 60, tokens: 400_000, now: now),
            // A much smaller, unrelated burst far outside that window.
            sample(minutesAgo: 2 * 24 * 60, tokens: 10_000, now: now)
        ]

        let suggestion = BudgetCalibrator.suggestBudget(from: samples)

        // 1,000,000 * 1.2 = 1,200,000, rounded up to the next 250k step.
        XCTAssertEqual(suggestion, 1_250_000)
    }

    func testNeverSuggestsBelowOneRoundingStep() {
        let now = Date()
        let samples = [sample(minutesAgo: 1, tokens: 10, now: now)]

        let suggestion = BudgetCalibrator.suggestBudget(from: samples)

        XCTAssertEqual(suggestion, 250_000)
    }
}
