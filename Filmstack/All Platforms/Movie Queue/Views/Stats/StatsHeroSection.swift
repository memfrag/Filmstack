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

    let stats: WatchedStats
    let granularity: WatchedStats.Granularity

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
        .onChange(of: granularity) { reveal() }
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
            if let first = stats.months.first?.start {
                Text("Since \(first.formatted(.dateTime.month(.wide).year()))")
                    .font(.subheadline)
                    .foregroundStyle(Palette.textSecondary)
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

    // MARK: - Secondary

    @ViewBuilder private var secondaryTiles: some View {
        let year = stats.currentYear
        let thisYear = stats.count(inYear: year)
        let best = stats.best(granularity)
        // "In 2026" says nothing new when everything was watched this year,
        // or when this year is also the best year shown beside it.
        let showsThisYear = thisYear != stats.total
            && !(granularity == .year && best.map { stats.calendar.component(.year, from: $0.start) == year } == true)

        if showsThisYear {
            tile("In \(String(year))", value: "\(thisYear)")
        }
        tile(granularity == .month ? "Per Month" : "Per Year",
             value: stats.average(granularity).formatted(.number.precision(.fractionLength(1))))
        if let best {
            tile(granularity == .month ? "Best Month" : "Best Year", value: "\(best.count)",
                 detail: granularity == .month
                    ? best.start.formatted(.dateTime.month(.abbreviated).year())
                    : best.start.formatted(.dateTime.year()))
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
