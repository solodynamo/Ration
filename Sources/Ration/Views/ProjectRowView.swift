import SwiftUI

struct ProjectRowView: View {
    let project: ProjectShare
    let maxTokens: Int

    private var share: Double {
        guard maxTokens > 0 else { return 0 }
        return Double(project.tokens) / Double(maxTokens)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(project.name)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                Spacer()
                Text(TokenFormatter.short(project.tokens))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
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
