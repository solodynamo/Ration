import Foundation

struct BranchShare: Identifiable {
    var id: String { name }
    let name: String
    let tokens: Int
}

struct ProjectShare: Identifiable {
    var id: String { name }
    let name: String
    let tokens: Int
    /// Sorted descending by tokens. Only meaningful (>1 entry) for projects
    /// where work actually happened on more than one branch — most repos
    /// will just have their one branch here, in which case the UI has
    /// nothing new to say and skips the drill-down entirely.
    let branches: [BranchShare]
}

/// One calendar day's token total — the building block for the weekly
/// trend. What Ration can show that a single Claude Code session never can:
/// not "your usage right now" but "your usage over time, across every
/// project you touched."
struct DayUsage: Identifiable {
    var id: Date { day }
    let day: Date
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
    /// Oldest to newest, always exactly 7 entries ending today.
    let last7Days: [DayUsage]
    /// API-equivalent value of the last 7 days, at public list pricing —
    /// not a claim about what you were actually billed (most Claude Code
    /// users are on a flat-fee subscription, not metered per-token). Nil
    /// only when every sample in the window used a model with no price in
    /// the table; a mix of known and unknown models still sums what it can
    /// price, since a partial "at least this much" is more honest than
    /// hiding the number over one unrecognized turn.
    let weekCostUSD: Double?
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

    var weekTokens: Int {
        last7Days.reduce(0) { $0 + $1.tokens }
    }

    /// Consecutive active days counting back from today. Capped at 7 since
    /// that's all the history `last7Days` covers.
    var streakDays: Int {
        var streak = 0
        for day in last7Days.reversed() {
            guard day.tokens > 0 else { break }
            streak += 1
        }
        return streak
    }

    var busiestDay: DayUsage? {
        last7Days.max { $0.tokens < $1.tokens }
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
            last7Days: [],
            weekCostUSD: nil,
            lastUpdated: Date()
        )
    }
}
