import Foundation

/// Picks a sensible starting budget from the user's own usage history so
/// first launch doesn't require typing anything in. Finds the busiest
/// 5-hour stretch in the lookback period and pads it, so a real session
/// doesn't start the ring already near the top.
enum BudgetCalibrator {
    private static let paddingFactor = 1.2
    private static let roundingStep = 250_000

    static func suggestBudget(from samples: [UsageSample]) -> Int? {
        guard !samples.isEmpty else { return nil }
        let sorted = samples.sorted { $0.timestamp < $1.timestamp }

        var maxWindowTotal = 0
        var runningTotal = 0
        var start = 0

        for end in sorted.indices {
            runningTotal += sorted[end].totalTokens
            while sorted[end].timestamp.timeIntervalSince(sorted[start].timestamp) > UsageAggregator.windowDuration {
                runningTotal -= sorted[start].totalTokens
                start += 1
            }
            maxWindowTotal = max(maxWindowTotal, runningTotal)
        }

        guard maxWindowTotal > 0 else { return nil }
        return roundUp(Int(Double(maxWindowTotal) * paddingFactor))
    }

    private static func roundUp(_ value: Int) -> Int {
        let rounded = ((value + roundingStep - 1) / roundingStep) * roundingStep
        return max(rounded, roundingStep)
    }
}
