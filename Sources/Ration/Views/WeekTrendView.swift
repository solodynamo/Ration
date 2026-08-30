import SwiftUI

/// The one thing a single Claude Code session can never tell you: the
/// shape of your week. No axis, no legend, no per-bar numbers — a glance
/// at the shape plus one sentence naming the outlier is the whole feature.
struct WeekTrendView: View {
    let days: [DayUsage]
    private let calendar = Calendar.current

    private var maxTokens: Int {
        days.map(\.tokens).max() ?? 0
    }

    private var busiestDay: DayUsage? {
        days.max { $0.tokens < $1.tokens }
    }

    private func weekdayInitial(_ date: Date) -> String {
        let symbols = calendar.veryShortWeekdaySymbols
        let index = calendar.component(.weekday, from: date) - 1
        return symbols.indices.contains(index) ? symbols[index] : ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("This week")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)

            HStack(alignment: .bottom, spacing: 5) {
                ForEach(days) { day in
                    VStack(spacing: 3) {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(Color.primary.opacity(calendar.isDateInToday(day.day) ? 0.75 : 0.3))
                            .frame(height: barHeight(for: day.tokens))
                        Text(weekdayInitial(day.day))
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 32, alignment: .bottom)

            if let busiestDay, busiestDay.tokens > 0 {
                Text("Busiest: \(dayLabel(busiestDay.day)) · \(TokenFormatter.short(busiestDay.tokens))")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func barHeight(for tokens: Int) -> CGFloat {
        guard maxTokens > 0 else { return 3 }
        return max(3, CGFloat(tokens) / CGFloat(maxTokens) * 26)
    }

    private func dayLabel(_ date: Date) -> String {
        if calendar.isDateInToday(date) { return "Today" }
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEE")
        return formatter.string(from: date)
    }
}
