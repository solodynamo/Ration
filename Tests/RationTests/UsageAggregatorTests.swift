import XCTest
@testable import Ration

final class UsageAggregatorTests: XCTestCase {
    private func sample(minutesAgo: Double, tokens: Int, project: String = "repo-a", now: Date) -> UsageSample {
        UsageSample(
            id: UUID(),
            provider: .claudeCode,
            timestamp: now.addingTimeInterval(-minutesAgo * 60),
            project: project,
            sessionId: "s1",
            inputTokens: tokens,
            outputTokens: 0,
            cacheWriteTokens: 0,
            cacheReadTokens: 0
        )
    }

    func testWindowTokensOnlyCountsWithinRollingWindow() {
        let now = Date()
        let samples = [
            sample(minutesAgo: 10, tokens: 100, now: now),   // inside 5h window
            sample(minutesAgo: 6 * 60, tokens: 999, now: now) // outside 5h window
        ]

        let snapshot = UsageAggregator.aggregate(provider: .claudeCode, samples: samples, budget: 1_000, now: now)

        XCTAssertEqual(snapshot.windowTokens, 100)
    }

    func testTopProjectsSortedDescendingByTokens() {
        let now = Date()
        let samples = [
            sample(minutesAgo: 1, tokens: 50, project: "small", now: now),
            sample(minutesAgo: 1, tokens: 500, project: "big", now: now),
            sample(minutesAgo: 1, tokens: 200, project: "mid", now: now)
        ]

        let snapshot = UsageAggregator.aggregate(provider: .claudeCode, samples: samples, budget: 1_000, now: now)

        XCTAssertEqual(snapshot.topProjects.map(\.name), ["big", "mid", "small"])
    }

    func testWindowFractionClampsAtOne() {
        let now = Date()
        let samples = [sample(minutesAgo: 1, tokens: 5_000, now: now)]

        let snapshot = UsageAggregator.aggregate(provider: .claudeCode, samples: samples, budget: 1_000, now: now)

        XCTAssertEqual(snapshot.windowFraction, 1.0)
    }

    func testEmptySamplesProduceZeroedSnapshot() {
        let snapshot = UsageAggregator.aggregate(provider: .claudeCode, samples: [], budget: 1_000)

        XCTAssertEqual(snapshot.windowTokens, 0)
        XCTAssertEqual(snapshot.todayTokens, 0)
        XCTAssertTrue(snapshot.topProjects.isEmpty)
        XCTAssertNil(snapshot.minutesToExhaustion)
    }
}
