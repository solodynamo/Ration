import Foundation
import Combine

/// Owns the refresh loop and exposes the latest snapshot to the UI.
@MainActor
final class AppState: ObservableObject {
    @Published private(set) var snapshot: UsageSnapshot
    @Published private(set) var providerAvailable: Bool

    let budgetStore: BudgetStore

    private let provider: UsageProvider
    private var timer: Timer?
    private let refreshInterval: TimeInterval = 20
    private var cancellables: Set<AnyCancellable> = []

    init(provider: UsageProvider = ClaudeCodeLogProvider(), budgetStore: BudgetStore = BudgetStore()) {
        self.provider = provider
        self.budgetStore = budgetStore
        self.providerAvailable = provider.isAvailable()
        self.snapshot = .empty(provider.kind, budget: budgetStore.windowBudget)

        // `@Published` publishes on `willSet` — the emitted value is the
        // new one, but `budgetStore.windowBudget` itself hasn't been
        // written yet at the moment this closure runs. Re-reading it here
        // (as `refresh()` normally does) would rebuild the snapshot with
        // the *old* budget, and the UI wouldn't catch up until the next
        // timer tick. Use the value the publisher handed us instead.
        budgetStore.$windowBudget
            .sink { [weak self] newBudget in self?.refresh(budgetOverride: newBudget) }
            .store(in: &cancellables)
    }

    func start() {
        refresh()
        calibrateBudgetIfNeeded()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    /// Runs once ever, on first launch: sets the starting budget from the
    /// user's own history so they never have to type a number in.
    private func calibrateBudgetIfNeeded() {
        guard providerAvailable, !budgetStore.isCalibrated, !budgetStore.hasCustomized else { return }
        let lookback: TimeInterval = 14 * 24 * 60 * 60
        let since = Date().addingTimeInterval(-lookback)
        guard let samples = try? provider.fetchSamples(since: since),
              let suggestion = BudgetCalibrator.suggestBudget(from: samples)
        else { return }
        budgetStore.applyCalibratedDefault(suggestion)
    }

    func refresh(budgetOverride: Int? = nil) {
        providerAvailable = provider.isAvailable()
        guard providerAvailable else { return }

        // 7 days, not 24h: the weekly trend needs a full week of history.
        // windowTokens/todayTokens/burn rate all self-filter to their own
        // narrower slices, so widening this doesn't change their answers.
        let lookback: TimeInterval = 7 * 24 * 60 * 60
        let since = Date().addingTimeInterval(-lookback)

        do {
            let samples = try provider.fetchSamples(since: since)
            snapshot = UsageAggregator.aggregate(
                provider: provider.kind,
                samples: samples,
                budget: budgetOverride ?? budgetStore.windowBudget
            )
        } catch {
            // Leave the previous snapshot in place rather than blanking the UI.
        }
    }
}
