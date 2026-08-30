import Foundation

/// Persists the user's own personal token budget for the rolling window.
/// This is a self-set pacing target, not Anthropic's actual plan ceiling —
/// nothing on disk tells us that number, so Ration doesn't pretend to know it.
final class BudgetStore: ObservableObject {
    private static let key = "com.ration.windowBudget"
    private static let defaultBudget = 2_000_000

    @Published var windowBudget: Int {
        didSet { UserDefaults.standard.set(windowBudget, forKey: Self.key) }
    }

    init() {
        let stored = UserDefaults.standard.integer(forKey: Self.key)
        self.windowBudget = stored > 0 ? stored : Self.defaultBudget
    }
}
