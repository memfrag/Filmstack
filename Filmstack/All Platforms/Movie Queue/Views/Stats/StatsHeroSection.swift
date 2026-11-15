//
//  Filmstack
//

import SwiftUI

extension Movie {
    /// The statistics' view of this movie; nil until it has a watch date.
    var watchedEntry: WatchedEntry? {
        guard let dateWatched else { return nil }
        return WatchedEntry(id: id, title: title, dateWatched: dateWatched, rating: userRating,
                            genres: genres, director: director, moods: moodTags)
    }
}

/// A small caps heading for a Statistics section.
struct StatsSectionTitle: View {
    let title: LocalizedStringKey
    var body: some View {
        Text(title)
            .font(.caption.weight(.bold))
            .tracking(1.2)
            .textCase(.uppercase)
            .foregroundStyle(Palette.accentBright)
            .accessibilityAddTraits(.isHeader)
    }
}

/// The big total and a few supporting numbers.
struct StatsHeroSection: View {

    /// Statistics already scoped to the selected year (or all time).
    let stats: WatchedStats
    let scope: WatchedStatsView.Scope
    /// Movies watched the year before, for a comparison tile.
    let previousYearCount: Int?

    private var granularity: WatchedStats.Granularity { scope.granularity }

    /// The total as drawn; counts up from zero when the screen appears.
    @State private var shownTotal = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var heroSize: CGFloat = 64

    var body: some View {
        VStack(spacing: 12) {
            heroCard
            ViewThatFits(in: .horizontal) {
                // Equal heights, whichever tile has the extra line.
                HStack(spacing: 12) { secondaryTiles }
                    .fixedSize(horizontal: false, vertical: true)
                VStack(spacing: 12) { secondaryTiles }
            }
        }
        .onAppear { reveal() }
        .onChange(of: stats.total) { reveal() }
        .onChange(of: scope) { reveal() }
    }

    private func reveal() {
        if reduceMotion {
            shownTotal = stats.total
        } else {
            shownTotal = 0
            withAnimation(.smooth(duration: 0.9).delay(0.1)) { shownTotal = stats.total }
        }
    }

    // MARK: - Hero

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Movies Watched", systemImage: "clapperboard.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.accentBright)
            Text("\(shownTotal)")
                .font(.system(size: heroSize, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(shownTotal)))
                .foregroundStyle(Palette.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            if let caption {
                Text(caption)
                    .font(.subheadline)
                    .foregroundStyle(Palette.textSecondary)
                    .contentTransition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background {
            // Clapperboard art, anchored right so it sits beside the number,
            // with a scrim on the left keeping the text readable.
            Image("StatsHeroBackground")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                .overlay {
                    LinearGradient(colors: [Palette.base.opacity(0.55), .clear],
                                   startPoint: .leading, endPoint: .center)
                }
                .accessibilityHidden(true)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Palette.accentBright.opacity(0.18))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(stats.total) movies watched")
    }

    /// "So far in 2026", "In 2025" or "Since May 2025".
    private var caption: String? {
        switch scope {
        case .year(let year):
            year == stats.currentYear
                ? String(localized: "So far in \(String(year))")
                : String(localized: "In \(String(year))")
        case .allTime:
            stats.entries.last.map {
                String(localized: "Since \($0.dateWatched.formatted(.dateTime.month(.wide).year()))")
            }
        }
    }

    // MARK: - Secondary

    @ViewBuilder private var secondaryTiles: some View {
        let best = stats.best(granularity)
        tile(granularity == .month ? "Per Month" : "Per Year",
             value: stats.average(granularity).formatted(.number.precision(.fractionLength(1))))
        if let best {
            tile(granularity == .month ? "Best Month" : "Best Year", value: "\(best.count)",
                 detail: granularity == .month
                    ? best.start.formatted(.dateTime.month(.abbreviated).year())
                    : best.start.formatted(.dateTime.year()))
        }
        if case .year(let year) = scope, let previous = previousYearCount {
            let change = stats.total - previous
            tile("vs \(String(year - 1))", value: change > 0 ? "+\(change)" : "\(change)",
                 detail: "from \(previous)")
        }
    }

    private func tile(_ title: LocalizedStringKey, value: String, detail: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(Palette.textSecondary)
            Text(value)
                .font(.title2.weight(.bold).monospacedDigit())
                .contentTransition(.numericText())
                .foregroundStyle(Palette.textPrimary)
            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Palette.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
        .filmCard()
        .accessibilityElement(children: .combine)
    }
}
