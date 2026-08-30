import Foundation

/// Public API list pricing, per million tokens. Sourced directly from
/// https://platform.claude.com/docs/en/about-claude/pricing, fetched
/// 2026-08-31 — update this table (and the date above) when that page
/// changes, rather than guessing at prices that may have moved on.
///
/// This is deliberately API pricing, not a claim about what any specific
/// user pays: most Claude Code users are on a flat-fee subscription
/// (Pro/Max), not metered per-token billing. Anywhere this is surfaced in
/// the UI, it should read as "API-equivalent value," never as "you were
/// charged this."
enum ModelPricing {
    struct Rates {
        let input: Double
        let output: Double
        let cacheWrite5m: Double
        let cacheWrite1h: Double
        let cacheRead: Double
    }

    /// Ordered most-specific-first: several current-generation Opus minor
    /// versions share one price, and checking a bare "opus-4" before the
    /// more specific "opus-4-5"/"opus-4-8" etc. would misclassify them as
    /// the much pricier retired Opus 4/4.1 tier, since "opus-4" is a
    /// substring of all of those model IDs too.
    private static let table: [(match: String, rates: Rates)] = [
        ("fable-5", Rates(input: 10, output: 50, cacheWrite5m: 12.50, cacheWrite1h: 20, cacheRead: 1)),
        ("mythos-5", Rates(input: 10, output: 50, cacheWrite5m: 12.50, cacheWrite1h: 20, cacheRead: 1)),
        ("opus-5", Rates(input: 5, output: 25, cacheWrite5m: 6.25, cacheWrite1h: 10, cacheRead: 0.50)),
        ("opus-4-8", Rates(input: 5, output: 25, cacheWrite5m: 6.25, cacheWrite1h: 10, cacheRead: 0.50)),
        ("opus-4-7", Rates(input: 5, output: 25, cacheWrite5m: 6.25, cacheWrite1h: 10, cacheRead: 0.50)),
        ("opus-4-6", Rates(input: 5, output: 25, cacheWrite5m: 6.25, cacheWrite1h: 10, cacheRead: 0.50)),
        ("opus-4-5", Rates(input: 5, output: 25, cacheWrite5m: 6.25, cacheWrite1h: 10, cacheRead: 0.50)),
        ("opus-4-1", Rates(input: 15, output: 75, cacheWrite5m: 18.75, cacheWrite1h: 30, cacheRead: 1.50)),
        ("opus-4", Rates(input: 15, output: 75, cacheWrite5m: 18.75, cacheWrite1h: 30, cacheRead: 1.50)),
        ("sonnet-5", Rates(input: 2, output: 10, cacheWrite5m: 2.50, cacheWrite1h: 4, cacheRead: 0.20)),
        ("sonnet-4-6", Rates(input: 3, output: 15, cacheWrite5m: 3.75, cacheWrite1h: 6, cacheRead: 0.30)),
        ("sonnet-4-5", Rates(input: 3, output: 15, cacheWrite5m: 3.75, cacheWrite1h: 6, cacheRead: 0.30)),
        ("sonnet-4", Rates(input: 3, output: 15, cacheWrite5m: 3.75, cacheWrite1h: 6, cacheRead: 0.30)),
        ("haiku-4-5", Rates(input: 1, output: 5, cacheWrite5m: 1.25, cacheWrite1h: 2, cacheRead: 0.10)),
        ("haiku-3-5", Rates(input: 0.80, output: 4, cacheWrite5m: 1, cacheWrite1h: 1.60, cacheRead: 0.08))
    ]

    /// Nil for a model we don't have a price for (a future model this
    /// table hasn't been updated for) rather than a guessed number.
    static func rates(forModelID modelID: String?) -> Rates? {
        guard let modelID else { return nil }
        return table.first { modelID.contains($0.match) }?.rates
    }

    /// Nil when the sample's model isn't in the table — callers should
    /// treat that turn as "unknown cost," not "$0."
    static func estimatedCostUSD(for sample: UsageSample) -> Double? {
        guard let rates = rates(forModelID: sample.model) else { return nil }
        let write1h = Double(sample.cacheWrite1hTokens)
        let write5m = Double(max(sample.cacheWriteTokens - sample.cacheWrite1hTokens, 0))
        let total =
            Double(sample.inputTokens) * rates.input +
            Double(sample.outputTokens) * rates.output +
            Double(sample.cacheReadTokens) * rates.cacheRead +
            write5m * rates.cacheWrite5m +
            write1h * rates.cacheWrite1h
        return total / 1_000_000
    }
}
