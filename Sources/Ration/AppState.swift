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

        budgetStore.$windowBudget
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)
    }

    func start() {
        refresh()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func refresh() {
        providerAvailable = provider.isAvailable()
        guard providerAvailable else { return }

        let lookback: TimeInterval = 24 * 60 * 60
        let since = Date().addingTimeInterval(-lookback)

        do {
            let samples = try provider.fetchSamples(since: since)
            snapshot = UsageAggregator.aggregate(
                provider: provider.kind,
                samples: samples,
                budget: budgetStore.windowBudget
            )
        } catch {
            // Leave the previous snapshot in place rather than blanking the UI.
        }
    }
}
