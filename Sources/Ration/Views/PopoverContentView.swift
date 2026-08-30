import SwiftUI
import AppKit

struct PopoverContentView: View {
    @ObservedObject var appState: AppState
    @State private var showingSettings = false

    var body: some View {
        Group {
            if showingSettings {
                SettingsView(budgetStore: appState.budgetStore)
                    .overlay(alignment: .topLeading) {
                        Button { showingSettings = false } label: {
                            Image(systemName: "chevron.left")
                        }
                        .buttonStyle(.plain)
                        .padding(16)
                    }
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
                Button { showingSettings = true } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                ZStack {
                    RingView(fraction: snapshot.windowFraction, lineWidth: 7)
                        .frame(width: 60, height: 60)
                    Text("\(Int(snapshot.windowFraction * 100))%")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(TokenFormatter.short(snapshot.windowTokens)) / \(TokenFormatter.short(snapshot.windowBudget))")
                        .font(.system(size: 12, weight: .medium))
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
