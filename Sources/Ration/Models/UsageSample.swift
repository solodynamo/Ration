import Foundation

/// One accounted turn of AI usage, normalized across providers.
struct UsageSample: Identifiable {
    let id: UUID
    let provider: ProviderKind
    let timestamp: Date
    let project: String
    /// Nil when Claude Code wasn't in a git repo for this turn (e.g. an
    /// "Other" bucket project) or didn't record one.
    let gitBranch: String?
    let sessionId: String
    let inputTokens: Int
    let outputTokens: Int
    let cacheWriteTokens: Int
    let cacheReadTokens: Int
    /// Which model wrote this turn (e.g. "claude-sonnet-5"), straight from
    /// the transcript. Nil for older logs that predate this field. Needed
    /// to price a turn — different models bill at very different rates.
    let model: String?
    /// The portion of `cacheWriteTokens` written to a 1-hour cache rather
    /// than the default 5-minute cache. Anthropic bills 1-hour writes at
    /// 2x the base input rate vs. 1.25x for 5-minute writes, so this split
    /// matters for an accurate cost estimate; it doesn't matter for
    /// `totalTokens`, which only cares about the combined total.
    let cacheWrite1hTokens: Int

    init(
        id: UUID,
        provider: ProviderKind,
        timestamp: Date,
        project: String,
        gitBranch: String?,
        sessionId: String,
        inputTokens: Int,
        outputTokens: Int,
        cacheWriteTokens: Int,
        cacheReadTokens: Int,
        model: String? = nil,
        cacheWrite1hTokens: Int = 0
    ) {
        self.id = id
        self.provider = provider
        self.timestamp = timestamp
        self.project = project
        self.gitBranch = gitBranch
        self.sessionId = sessionId
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheWriteTokens = cacheWriteTokens
        self.cacheReadTokens = cacheReadTokens
        self.model = model
        self.cacheWrite1hTokens = cacheWrite1hTokens
    }

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
