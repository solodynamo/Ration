import SwiftUI

struct ProjectRowView: View {
    let project: ProjectShare
    let maxTokens: Int
    @State private var isExpanded = false

    private var share: Double {
        guard maxTokens > 0 else { return 0 }
        return Double(project.tokens) / Double(maxTokens)
    }

    /// A single-branch project has nothing the top-line row didn't already
    /// say, so there's no drill-down to offer.
    private var hasBranchBreakdown: Bool {
        project.branches.count > 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { isExpanded.toggle() }
            } label: {
                HStack {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .opacity(hasBranchBreakdown ? 1 : 0)
                    Text(project.name)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                    Spacer()
                    Text(TokenFormatter.short(project.tokens))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!hasBranchBreakdown)

            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.secondary.opacity(0.15))
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.accentColor.opacity(0.8))
                            .frame(width: geo.size.width * share)
                    }
            }
            .frame(height: 4)

            if isExpanded && hasBranchBreakdown {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(project.branches) { branch in
                        HStack {
                            Text(branch.name)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Spacer()
                            Text(TokenFormatter.short(branch.tokens))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.leading, 13)
                .padding(.top, 1)
            }
        }
    }
}

enum TokenFormatter {
    static func short(_ value: Int) -> String {
        switch value {
        case 1_000_000...:
            return String(format: "%.1fM", Double(value) / 1_000_000)
        case 1_000...:
            return String(format: "%.1fK", Double(value) / 1_000)
        default:
            return "\(value)"
        }
    }
}

enum CostFormatter {
    static func short(_ dollars: Double) -> String {
        switch dollars {
        case 1_000...:
            return String(format: "$%.1fK", dollars / 1_000)
        case 1...:
            return String(format: "$%.0f", dollars)
        default:
            return String(format: "$%.2f", dollars)
        }
    }
}
