import SwiftUI

struct SettingsView: View {
    @ObservedObject var budgetStore: BudgetStore
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    /// SettingsView is swapped in via a plain `if` in PopoverContentView,
    /// not a `.sheet`/NavigationStack, so `@Environment(\.dismiss)` has no
    /// presentation to dismiss and silently does nothing. This closure is
    /// the only thing that actually closes the screen.
    let onDone: () -> Void

    private let budgetOptionsM: [Double] = [0.5, 1, 2, 3, 5, 8]

    private var budgetBinding: Binding<Int> {
        Binding(
            get: { budgetStore.windowBudget },
            set: { budgetStore.setUserBudget($0) }
        )
    }

    private var footnote: String {
        if budgetStore.windowBudget == 0 {
            return "Ration will just show your usage — no ring, no warnings, no pacing target."
        }
        return budgetStore.hasCustomized
            ? "This is a personal pacing target, not Anthropic's actual plan limit — that number isn't published anywhere Ration can read."
            : "Auto-set from your busiest recent 5-hour stretch. Pick a value here anytime to take over — it won't be recalculated after that."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.system(size: 13, weight: .semibold))

            VStack(alignment: .leading, spacing: 6) {
                Text("5-hour budget")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Picker("", selection: budgetBinding) {
                    Text("No budget").tag(0)
                    ForEach(budgetOptionsM, id: \.self) { millions in
                        Text("\(millions.formatted()) M tokens")
                            .tag(Int(millions * 1_000_000))
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                Text(footnote)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Toggle("Launch at login", isOn: $launchAtLogin)
                .font(.system(size: 12))
                .onChange(of: launchAtLogin) { newValue in
                    LaunchAtLogin.set(newValue)
                }

            Button("Done") { onDone() }
                .frame(maxWidth: .infinity)
        }
        .padding(16)
        .frame(width: 260)
    }
}
