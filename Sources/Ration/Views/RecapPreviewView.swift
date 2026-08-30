import SwiftUI

/// Popover-sized wrapper around RecapCardView: a shrunk preview plus the
/// two things you can actually do with it. No accounts, no upload — Copy
/// and Save just hand you a PNG, the same as any other macOS share sheet.
struct RecapPreviewView: View {
    let snapshot: UsageSnapshot
    let onDone: () -> Void

    @State private var feedback: String?

    private static let previewScale: CGFloat = 0.62

    private var card: RecapCardView {
        RecapCardView(
            weekTokens: snapshot.weekTokens,
            streakDays: snapshot.streakDays,
            busiestDay: snapshot.busiestDay,
            weekCostUSD: snapshot.weekCostUSD,
            generatedOn: Date()
        )
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Button { onDone() } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                Text("Share your week")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
            }

            card
                .scaleEffect(Self.previewScale)
                .frame(
                    width: RecapCardView.cardSize.width * Self.previewScale,
                    height: RecapCardView.cardSize.height * Self.previewScale
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.2))
                )

            HStack(spacing: 8) {
                Button("Copy") { copy() }
                Button("Save…") { save() }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Text(feedback ?? " ")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(width: 260)
    }

    private func copy() {
        guard let image = RecapImageExporter.renderImage(for: card) else { return }
        RecapImageExporter.copyToClipboard(image)
        feedback = "Copied — paste it anywhere"
    }

    private func save() {
        guard let image = RecapImageExporter.renderImage(for: card) else {
            feedback = nil
            return
        }
        let saved = RecapImageExporter.saveToDisk(image, suggestedName: "Ration-week.png")
        feedback = saved ? "Saved" : nil
    }
}
