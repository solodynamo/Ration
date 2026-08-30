import SwiftUI
import AppKit

struct PopoverContentView: View {
    @ObservedObject var appState: AppState
    @State private var showingSettings = false
    @State private var showingRecap = false

    var body: some View {
        Group {
            if showingSettings {
                SettingsView(budgetStore: appState.budgetStore, onDone: { showingSettings = false })
            } else if showingRecap {
                RecapPreviewView(snapshot: appState.snapshot, onDone: { showingRecap = false })
            } else if !appState.providerAvailable {
                emptyState
            } else {
                mainContent
            }
        }
        .frame(width: 260)
    }

    private var mainContent: some View {
        let snapshot = appState.snapshot

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(snapshot.provider.rawValue)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button { showingRecap = true } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                Button { showingSettings = true } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            if appState.budgetStore.isCalibrated,
               !appState.budgetStore.hasCustomized,
               !appState.budgetStore.calibrationBannerDismissed {
                calibrationBanner
            }

            HStack(spacing: 16) {
                ZStack {
                    RingView(fraction: snapshot.windowFraction, lineWidth: 7)
                        .frame(width: 60, height: 60)
                    if snapshot.windowBudget > 0 {
                        Text("\(Int(snapshot.windowFraction * 100))%")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                    } else {
                        Image(systemName: "infinity")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    if snapshot.windowBudget > 0 {
                        Text("\(TokenFormatter.short(snapshot.windowTokens)) / \(TokenFormatter.short(snapshot.windowBudget))")
                            .font(.system(size: 12, weight: .medium))
                    } else {
                        Text("\(TokenFormatter.short(snapshot.windowTokens)) — no budget set")
                            .font(.system(size: 12, weight: .medium))
                    }
                    Text("this 5h window")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)

                    if let minutes = snapshot.minutesToExhaustion {
                        Text("~\(formatMinutes(minutes)) left at current pace")
                            .font(.system(size: 10))
                            .foregroundStyle(.orange)
                    }
                }
            }

            Divider()

            HStack {
                Label("Today", systemImage: "sun.max")
                Spacer()
                Text(TokenFormatter.short(snapshot.todayTokens))
                    .foregroundStyle(.secondary)
            }
            .font(.system(size: 12))

            HStack {
                Label("Burn rate", systemImage: "flame")
                Spacer()
                Text("\(TokenFormatter.short(Int(snapshot.tokensPerMinute))) / min")
                    .foregroundStyle(.secondary)
            }
            .font(.system(size: 12))

            if !snapshot.topProjects.isEmpty {
                Divider()
                Text("Top projects — this window")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                VStack(spacing: 8) {
                    ForEach(snapshot.topProjects) { project in
                        ProjectRowView(project: project, maxTokens: snapshot.topProjects.first?.tokens ?? 1)
                    }
                }
            }

            if snapshot.last7Days.contains(where: { $0.tokens > 0 }) {
                Divider()
                WeekTrendView(days: snapshot.last7Days)
            }

            Divider()
            Button("Quit Ration") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
        }
        .padding(16)
    }

    private var calibrationBanner: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 10))
            Text("Budget auto-set from your usage. Adjust anytime in Settings.")
                .font(.system(size: 10))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button {
                appState.budgetStore.calibrationBannerDismissed = true
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9))
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(.secondary)
        .padding(8)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 24))
                .foregroundStyle(.secondary)
            Text("No Claude Code activity found")
                .font(.system(size: 12, weight: .medium))
            Text("Ration reads local session logs from ~/.claude/projects. Run Claude Code at least once to see usage here.")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Quit Ration") { NSApplication.shared.terminate(nil) }
                .font(.system(size: 11))
                .padding(.top, 4)
        }
        .padding(20)
    }

    private func formatMinutes(_ minutes: Double) -> String {
        if minutes >= 60 {
            let hours = minutes / 60
            return String(format: "%.1fh", hours)
        }
        return "\(Int(minutes))m"
    }
}
