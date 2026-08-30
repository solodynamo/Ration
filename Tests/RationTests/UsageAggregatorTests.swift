import XCTest
@testable import Ration

final class UsageAggregatorTests: XCTestCase {
    private func sample(minutesAgo: Double, tokens: Int, project: String = "repo-a", gitBranch: String? = nil, model: String? = nil, now: Date) -> UsageSample {
        UsageSample(
            id: UUID(),
            provider: .claudeCode,
            timestamp: now.addingTimeInterval(-minutesAgo * 60),
            project: project,
            gitBranch: gitBranch,
            sessionId: "s1",
            inputTokens: tokens,
            outputTokens: 0,
            cacheWriteTokens: 0,
            cacheReadTokens: 0,
            model: model
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

    func testProjectTokensSplitByBranchDescending() {
        let now = Date()
        let samples = [
            sample(minutesAgo: 1, tokens: 300, project: "repo", gitBranch: "main", now: now),
            sample(minutesAgo: 1, tokens: 700, project: "repo", gitBranch: "feature/x", now: now)
        ]

        let snapshot = UsageAggregator.aggregate(provider: .claudeCode, samples: samples, budget: 1_000, now: now)

        XCTAssertEqual(snapshot.topProjects.count, 1)
        let repo = snapshot.topProjects[0]
        XCTAssertEqual(repo.tokens, 1_000)
        XCTAssertEqual(repo.branches.map(\.name), ["feature/x", "main"])
        XCTAssertEqual(repo.branches.map(\.tokens), [700, 300])
    }

    func testWeekTokensSumsAllSevenDays() {
        let now = Date()
        let samples = [
            sample(minutesAgo: 10, tokens: 100, now: now),                 // today
            sample(minutesAgo: 3 * 24 * 60, tokens: 250, now: now)         // 3 days ago
        ]

        let snapshot = UsageAggregator.aggregate(provider: .claudeCode, samples: samples, budget: 1_000, now: now)

        XCTAssertEqual(snapshot.weekTokens, 350)
    }

    func testStreakDaysStopsAtFirstGapCountingBackFromToday() {
        let now = Date()
        let samples = [
            sample(minutesAgo: 10, tokens: 50, now: now),                  // today: active
            sample(minutesAgo: 1 * 24 * 60 + 10, tokens: 50, now: now),    // yesterday: active
            // 2 days ago: no usage (gap)
            sample(minutesAgo: 3 * 24 * 60 + 10, tokens: 50, now: now)     // 3 days ago: active, but past the gap
        ]

        let snapshot = UsageAggregator.aggregate(provider: .claudeCode, samples: samples, budget: 1_000, now: now)

        XCTAssertEqual(snapshot.streakDays, 2)
    }

    func testWeekCostUSDSumsPriceableSamplesInTheSevenDayWindow() {
        let now = Date()
        let samples = [
            // 1,000,000 input tokens on Sonnet 5 ($2/MTok) = $2, inside the week
            sample(minutesAgo: 10, tokens: 1_000_000, model: "claude-sonnet-5", now: now),
            // priceable but 10 days old — outside the week, must not count
            sample(minutesAgo: 10 * 24 * 60, tokens: 1_000_000, model: "claude-sonnet-5", now: now)
        ]

        let snapshot = UsageAggregator.aggregate(provider: .claudeCode, samples: samples, budget: 1_000, now: now)

        XCTAssertEqual(snapshot.weekCostUSD!, 2.0, accuracy: 0.0001)
    }

    func testWeekCostUSDIsNilWhenNoSampleHasAKnownModel() {
        let now = Date()
        let samples = [sample(minutesAgo: 10, tokens: 1_000, model: nil, now: now)]

        let snapshot = UsageAggregator.aggregate(provider: .claudeCode, samples: samples, budget: 1_000, now: now)

        XCTAssertNil(snapshot.weekCostUSD)
    }

    func testSingleBranchProjectStillReportsThatOneBranch() {
        let now = Date()
        let samples = [sample(minutesAgo: 1, tokens: 100, project: "repo", gitBranch: "main", now: now)]

        let snapshot = UsageAggregator.aggregate(provider: .claudeCode, samples: samples, budget: 1_000, now: now)

        XCTAssertEqual(snapshot.topProjects[0].branches.map(\.name), ["main"])
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

    func testLast7DaysBucketsByCalendarDayOldestFirst() {
        let now = Date()
        let samples = [
            sample(minutesAgo: 10, tokens: 100, now: now),               // today
            sample(minutesAgo: 2 * 24 * 60, tokens: 300, now: now),      // 2 days ago
            sample(minutesAgo: 10 * 24 * 60, tokens: 999, now: now)      // outside the 7-day window
        ]

        let snapshot = UsageAggregator.aggregate(provider: .claudeCode, samples: samples, budget: 1_000, now: now)

        XCTAssertEqual(snapshot.last7Days.count, 7)
        XCTAssertLessThan(snapshot.last7Days.first!.day, snapshot.last7Days.last!.day)
        XCTAssertEqual(snapshot.last7Days.last?.tokens, 100)
        XCTAssertEqual(snapshot.last7Days[snapshot.last7Days.count - 3].tokens, 300)
        XCTAssertEqual(snapshot.last7Days.reduce(0) { $0 + $1.tokens }, 400) // the 10-day-old sample is excluded
    }
}
