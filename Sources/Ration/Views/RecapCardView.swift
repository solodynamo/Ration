import SwiftUI

/// The one Ration screen designed to leave the app — and the one place
/// where "no chrome, no gradients" is the wrong instinct. Everything else
/// in this app is built to be glanced at for a second in the menu bar;
/// this is built to be looked at on someone else's timeline, where it's
/// competing with everything else in their feed. That means it gets to be
/// loud: a fixed dark background (not adapting to the *viewer's* light/dark
/// setting, the same way Spotify Wrapped always looks the same regardless
/// of your phone theme), a badge that names the achievement instead of
/// just reporting a number, and a hero number big enough to read at
/// thumbnail size.
struct RecapCardView: View {
    let weekTokens: Int
    let streakDays: Int
    let busiestDay: DayUsage?
    /// API-equivalent value at public list pricing — not a claim about an
    /// actual bill, since most Claude Code users are on a flat-fee
    /// subscription. Nil when no sample in the window had a priceable
    /// model, in which case the line is simply omitted.
    let weekCostUSD: Double?
    let generatedOn: Date

    static let cardSize = CGSize(width: 360, height: 440)

    /// Named tiers instead of a bare streak count — "5" is a number,
    /// "On Fire" is something you'd want people to see next to your name.
    /// Thresholds are honest claims about the user's own data, never a
    /// comparison to anyone else (Ration has no backend to know that).
    private var badge: (emoji: String, label: String) {
        switch streakDays {
        case 7: return ("🔥", "Unstoppable")
        case 5...6: return ("🔥", "On Fire")
        case 3...4: return ("⚡️", "On a Roll")
        case 1...2: return ("🌱", "Warming Up")
        default: return ("💤", "Back From a Break")
        }
    }

    private var dateRangeLabel: String {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMMd")
        let start = Calendar.current.date(byAdding: .day, value: -6, to: generatedOn) ?? generatedOn
        return "\(formatter.string(from: start)) – \(formatter.string(from: generatedOn))"
    }

    private func weekdayName(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEEE")
        return formatter.string(from: date)
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("MY VIBECODING WEEK")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(.orange)
                Text(dateRangeLabel)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 14)

            Text("\(badge.emoji) \(badge.label)")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.12))
                .clipShape(Capsule())

            Spacer(minLength: 20)

            VStack(spacing: 4) {
                Text(TokenFormatter.short(weekTokens))
                    .font(.system(size: 72, weight: .heavy, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .orange.opacity(0.9)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                Text("tokens with Claude Code")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                if let weekCostUSD {
                    Text("≈ \(CostFormatter.short(weekCostUSD)) in API value")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.orange)
                        .padding(.top, 2)
                }
            }

            Spacer(minLength: 26)

            HStack(spacing: 0) {
                statBlock(value: "\(streakDays)", label: streakDays == 1 ? "day streak" : "day streak")
                Rectangle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 1, height: 32)
                statBlock(value: busiestDay.map { weekdayName($0.day) } ?? "—", label: "busiest day")
            }

            Spacer(minLength: 22)

            HStack(spacing: 6) {
                Circle()
                    .trim(from: 0, to: 0.72)
                    .stroke(Color.orange, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 14, height: 14)
                Text("Ration")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text("github.com/solodynamo/Ration")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .padding(28)
        .frame(width: Self.cardSize.width, height: Self.cardSize.height)
        .background(
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.08, green: 0.08, blue: 0.1), .black],
                    startPoint: .top,
                    endPoint: .bottom
                )
                RadialGradient(
                    colors: [.orange.opacity(0.35), .clear],
                    center: .init(x: 0.5, y: 0.42),
                    startRadius: 0,
                    endRadius: 220
                )
            }
        )
    }

    private func statBlock(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }
}
