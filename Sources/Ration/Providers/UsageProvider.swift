import Foundation

/// Something that can report normalized usage samples for a lookback window.
/// Each CLI tool gets its own conforming type; the rest of the app never
/// needs to know how a given provider sources its data.
protocol UsageProvider {
    var kind: ProviderKind { get }

    /// Whether this provider has usable local data on this machine right now.
    func isAvailable() -> Bool

    /// Returns samples with `timestamp >= since`, oldest first.
    func fetchSamples(since: Date) throws -> [UsageSample]
}
