import Foundation

struct ProjectShare: Identifiable {
    var id: String { name }
    let name: String
    let tokens: Int
}

/// Aggregated, ready-to-render usage state for a single provider.
struct UsageSnapshot {
    let provider: ProviderKind
    let windowTokens: Int
    let windowBudget: Int
    let windowStart: Date
    let todayTokens: Int
    let tokensPerMinute: Double
    let topProjects: [ProjectShare]
    let lastUpdated: Date

    var windowFraction: Double {
        guard windowBudget > 0 else { return 0 }
        return min(Double(windowTokens) / Double(windowBudget), 1.0)
    }

    /// Minutes until the configured budget is exhausted at the current pace.
    /// Nil when there's no meaningful pace or the budget is already blown.
    var minutesToExhaustion: Double? {
        guard tokensPerMinute > 0.01 else { return nil }
        let remaining = Double(windowBudget - windowTokens)
        guard remaining > 0 else { return nil }
        return remaining / tokensPerMinute
    }

    static func empty(_ provider: ProviderKind, budget: Int) -> UsageSnapshot {
        UsageSnapshot(
            provider: provider,
            windowTokens: 0,
            windowBudget: budget,
            windowStart: Date(),
            todayTokens: 0,
            tokensPerMinute: 0,
            topProjects: [],
            lastUpdated: Date()
        )
    }
}
