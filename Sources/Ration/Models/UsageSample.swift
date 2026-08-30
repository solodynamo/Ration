import Foundation

/// One accounted turn of AI usage, normalized across providers.
struct UsageSample: Identifiable {
    let id: UUID
    let provider: ProviderKind
    let timestamp: Date
    let project: String
    let sessionId: String
    let inputTokens: Int
    let outputTokens: Int
    let cacheWriteTokens: Int
    let cacheReadTokens: Int

    /// Everything that counts against a rate-limit window, cache reads included
    /// since they still occupy request budget even though they're cheap.
    var totalTokens: Int {
        inputTokens + outputTokens + cacheWriteTokens + cacheReadTokens
    }
}

enum ProviderKind: String, CaseIterable, Identifiable {
    case claudeCode = "Claude Code"

    var id: String { rawValue }
}
