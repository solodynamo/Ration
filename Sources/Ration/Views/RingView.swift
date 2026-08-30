import SwiftUI

/// A minimal circular gauge. No chrome, no gradients — just a track and a
/// progress arc that shifts from green to red as `fraction` climbs.
struct RingView: View {
    let fraction: Double
    var lineWidth: CGFloat = 6

    private var color: Color {
        switch fraction {
        case ..<0.6: return .green
        case ..<0.85: return .yellow
        default: return .red
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(fraction, 0.001))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.4), value: fraction)
        }
    }
}

/// Tiny fixed-size ring meant for the menu bar status item itself.
struct MenuBarRing: View {
    let fraction: Double

    var body: some View {
        RingView(fraction: fraction, lineWidth: 2.5)
            .frame(width: 16, height: 16)
    }
}
