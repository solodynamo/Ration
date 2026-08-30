import XCTest
@testable import Ration

final class ModelPricingTests: XCTestCase {
    private func sample(
        model: String?,
        input: Int = 0,
        output: Int = 0,
        cacheWrite: Int = 0,
        cacheWrite1h: Int = 0,
        cacheRead: Int = 0
    ) -> UsageSample {
        UsageSample(
            id: UUID(),
            provider: .claudeCode,
            timestamp: Date(),
            project: "repo",
            gitBranch: nil,
            sessionId: "s1",
            inputTokens: input,
            outputTokens: output,
            cacheWriteTokens: cacheWrite,
            cacheReadTokens: cacheRead,
            model: model,
            cacheWrite1hTokens: cacheWrite1h
        )
    }

    func testUnknownModelReturnsNilNotAGuess() {
        XCTAssertNil(ModelPricing.estimatedCostUSD(for: sample(model: "some-future-model-nobody-has-heard-of")))
        XCTAssertNil(ModelPricing.estimatedCostUSD(for: sample(model: nil)))
    }

    func testSonnet5InputAndOutputPricing() {
        // $2/MTok input, $10/MTok output per platform.claude.com/docs/en/about-claude/pricing
        let cost = ModelPricing.estimatedCostUSD(for: sample(model: "claude-sonnet-5", input: 1_000_000, output: 1_000_000))
        XCTAssertEqual(cost!, 12.0, accuracy: 0.0001)
    }

    func testCacheReadIsMuchCheaperThanBaseInput() {
        // 0.1x base input rate for Sonnet 5 ($2) => $0.20/MTok
        let cost = ModelPricing.estimatedCostUSD(for: sample(model: "claude-sonnet-5", cacheRead: 1_000_000))
        XCTAssertEqual(cost!, 0.20, accuracy: 0.0001)
    }

    func testCacheWriteSplitsBetween5MinuteAnd1HourRates() {
        // Sonnet 5: 5m write = $2.50/MTok, 1h write = $4/MTok.
        // 1_000_000 total cache-write tokens, 400_000 of them 1h => 600_000 at 5m rate.
        let cost = ModelPricing.estimatedCostUSD(for: sample(
            model: "claude-sonnet-5",
            cacheWrite: 1_000_000,
            cacheWrite1h: 400_000
        ))
        let expected = (600_000.0 * 2.50 + 400_000.0 * 4.0) / 1_000_000
        XCTAssertEqual(cost!, expected, accuracy: 0.0001)
    }

    func testDateSuffixedModelIDsStillMatch() {
        // Real transcripts carry trailing version dates (e.g. from stats
        // history); the matcher must see through that via substring match.
        let cost = ModelPricing.estimatedCostUSD(for: sample(model: "claude-opus-4-5-20251101", input: 1_000_000))
        XCTAssertEqual(cost!, 5.0, accuracy: 0.0001)
    }

    func testCurrentOpusMinorVersionsAreNotMisclassifiedAsRetiredOpus4() {
        // "opus-4-5" contains "opus-4" as a substring — the matcher must
        // not let the more expensive retired-Opus-4 rate ($15) win over
        // the correct current-generation rate ($5).
        let cost = ModelPricing.estimatedCostUSD(for: sample(model: "claude-opus-4-5-20251101", input: 1_000_000))
        XCTAssertEqual(cost!, 5.0, accuracy: 0.0001) // not 15.0
    }

    func testRetiredOpus4StillPricedCorrectly() {
        let cost = ModelPricing.estimatedCostUSD(for: sample(model: "claude-opus-4-20250514", input: 1_000_000))
        XCTAssertEqual(cost!, 15.0, accuracy: 0.0001)
    }
}
