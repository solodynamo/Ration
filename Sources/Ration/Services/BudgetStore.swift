import Foundation

/// Persists the user's personal token budget for the rolling window. This is
/// a pacing target, not Anthropic's actual plan ceiling — nothing on disk
/// tells us that number, so Ration doesn't pretend to know it.
///
/// The first value ever set comes from `BudgetCalibrator`, which looks at
/// the user's own usage history — no typing required. Once the user picks a
/// value themselves in Settings, calibration never overwrites it again.
final class BudgetStore: ObservableObject {
    private static let budgetKey = "com.ration.windowBudget"
    private static let calibratedKey = "com.ration.budgetCalibrated"
    private static let customizedKey = "com.ration.budgetCustomized"
    private static let bannerDismissedKey = "com.ration.calibrationBannerDismissed"
    private static let fallbackDefault = 2_000_000

    @Published var windowBudget: Int {
        didSet { UserDefaults.standard.set(windowBudget, forKey: Self.budgetKey) }
    }

    /// True once a value — calibrated or user-picked — has ever been set.
    @Published private(set) var isCalibrated: Bool

    /// True once the user has picked a value themselves in Settings.
    @Published private(set) var hasCustomized: Bool

    @Published var calibrationBannerDismissed: Bool {
        didSet { UserDefaults.standard.set(calibrationBannerDismissed, forKey: Self.bannerDismissedKey) }
    }

    init() {
        let stored = UserDefaults.standard.integer(forKey: Self.budgetKey)
        self.windowBudget = stored > 0 ? stored : Self.fallbackDefault
        self.isCalibrated = UserDefaults.standard.bool(forKey: Self.calibratedKey)
        self.hasCustomized = UserDefaults.standard.bool(forKey: Self.customizedKey)
        self.calibrationBannerDismissed = UserDefaults.standard.bool(forKey: Self.bannerDismissedKey)
    }

    /// Called once, from history, on first launch. No-ops if a budget is
    /// already in place so it never clobbers a deliberate choice.
    func applyCalibratedDefault(_ suggested: Int) {
        guard !isCalibrated, !hasCustomized, suggested > 0 else { return }
        windowBudget = suggested
        isCalibrated = true
        UserDefaults.standard.set(true, forKey: Self.calibratedKey)
    }

    /// Called when the user picks a value themselves in Settings.
    func setUserBudget(_ value: Int) {
        windowBudget = value
        hasCustomized = true
        UserDefaults.standard.set(true, forKey: Self.customizedKey)
    }
}
