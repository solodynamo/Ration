import Foundation

/// Turns raw samples into the numbers the UI actually shows: rolling-window
/// total, today's total, current burn rate, and a per-project breakdown.
enum UsageAggregator {
    /// Claude's rate limits reset on a rolling window; this mirrors that
    /// shape so "time to exhaustion" means something.
    static let windowDuration: TimeInterval = 5 * 60 * 60

    /// Burn rate is measured over a short trailing slice so it reflects what
    /// you're doing *right now*, not an average since the window opened.
    static let burnRateLookback: TimeInterval = 15 * 60

    static func aggregate(
        provider: ProviderKind,
        samples: [UsageSample],
        budget: Int,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> UsageSnapshot {
        let windowStart = now.addingTimeInterval(-windowDuration)
        let windowSamples = samples.filter { $0.timestamp >= windowStart }
        let windowTokens = windowSamples.reduce(0) { $0 + $1.totalTokens }

        let dayStart = calendar.startOfDay(for: now)
        let todayTokens = samples
            .filter { $0.timestamp >= dayStart }
            .reduce(0) { $0 + $1.totalTokens }

        let burnStart = now.addingTimeInterval(-burnRateLookback)
        let burnSamples = windowSamples.filter { $0.timestamp >= burnStart }
        let burnTokens = burnSamples.reduce(0) { $0 + $1.totalTokens }
        let elapsedMinutes = max(now.timeIntervalSince(burnSamples.first?.timestamp ?? now) / 60, 1.0 / 60)
        let tokensPerMinute = burnSamples.isEmpty ? 0 : Double(burnTokens) / elapsedMinutes

        var perProject: [String: Int] = [:]
        for sample in windowSamples {
            perProject[sample.project, default: 0] += sample.totalTokens
        }
        let topProjects = perProject
            .map { ProjectShare(name: $0.key, tokens: $0.value) }
            .sorted { $0.tokens > $1.tokens }
            .prefix(5)

        return UsageSnapshot(
            provider: provider,
            windowTokens: windowTokens,
            windowBudget: budget,
            windowStart: windowStart,
            todayTokens: todayTokens,
            tokensPerMinute: tokensPerMinute,
            topProjects: Array(topProjects),
            lastUpdated: now
        )
    }
}
