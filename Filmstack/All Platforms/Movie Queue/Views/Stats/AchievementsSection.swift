//
//  Filmstack
//

import SwiftUI

/// Achievements earned from the watch history, in a horizontal row. Hidden
/// when none are earned yet.
struct AchievementsSection: View {

    var title: LocalizedStringKey = "Achievements"
    let achievements: [WatchedStats.Achievement]

    /// Flips once on appear to give each badge a single bounce.
    @State private var appeared = false

    var body: some View {
        if !achievements.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                StatsSectionTitle(title: title)
                ScrollView(.horizontal) {
                    HStack(spacing: 12) {
                        ForEach(achievements) { badge($0) }
                    }
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.hidden)
                .scrollClipDisabled()
            }
            .onAppear { appeared = true }
        }
    }

    private func badge(_ achievement: WatchedStats.Achievement) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: achievement.symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .symbolEffect(.bounce, value: appeared)
                .frame(width: 44, height: 44)
                .background(LinearGradient(colors: [Palette.accentBright, Palette.accent],
                                           startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: Circle())
                .shadow(color: Palette.accent.opacity(0.5), radius: 8)
            Text(achievement.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.textPrimary)
            Text(achievement.subtitle)
                .font(.caption)
                .foregroundStyle(Palette.textSecondary)
                .lineLimit(2, reservesSpace: true)
        }
        .frame(width: 150, alignment: .leading)
        .padding(14)
        .filmCard(cornerRadius: 16)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Achievement earned: \(achievement.title). \(achievement.subtitle)")
    }
}
