//
//  Filmstack
//

import SwiftUI

/// Posters of what was watched in the period picked on the chart. Tapping
/// one opens the movie.
struct PosterHistorySection: View {

    let stats: WatchedStats
    let granularity: WatchedStats.Granularity
    let period: Date
    let movie: (UUID) -> Movie?
    let onOpen: (UUID) -> Void

    var body: some View {
        let entries = stats.entries(in: period, granularity)
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(heading(count: entries.count))
                    .font(.headline)
                    .foregroundStyle(Palette.textPrimary)
                Spacer()
                Text(entries.count == 1 ? "1 movie" : "\(entries.count) movies")
                    .font(.subheadline)
                    .foregroundStyle(Palette.textSecondary)
            }
            if entries.isEmpty {
                Text("Nothing watched in \(periodName).")
                    .font(.subheadline)
                    .foregroundStyle(Palette.textSecondary)
                    .padding(.vertical, 8)
            } else {
                ScrollView(.horizontal) {
                    LazyHStack(alignment: .top, spacing: 12) {
                        ForEach(entries, id: \.id) { entry in
                            if let movie = movie(entry.id) {
                                posterButton(movie, entry: entry)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.hidden)
                .scrollClipDisabled()
            }
        }
    }

    private var periodName: String {
        granularity == .month
            ? period.formatted(.dateTime.month(.wide).year())
            : period.formatted(.dateTime.year())
    }

    private func heading(count: Int) -> String {
        if granularity == .month, count >= WatchedStats.Threshold.marathonMovies {
            return String(localized: "Your \(period.formatted(.dateTime.month(.wide))) Marathon")
        }
        return String(localized: "Watched in \(periodName)")
    }

    private func posterButton(_ movie: Movie, entry: WatchedEntry) -> some View {
        Button { onOpen(entry.id) } label: {
            VStack(alignment: .leading, spacing: 6) {
                PosterView(movie: movie, size: .queue, cornerRadius: 8)
                    .frame(width: 100)
                    .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
                Text(entry.title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(entry.dateWatched.formatted(.dateTime.day().month(.abbreviated)))
                    if let rating = entry.rating {
                        Text("·")
                        Image(systemName: "star.fill").imageScale(.small)
                        Text(rating.formatted(.number.precision(.fractionLength(0...1))))
                    }
                }
                .font(.caption2)
                .foregroundStyle(Palette.textSecondary)
            }
            .frame(width: 100, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(entry.title), watched \(entry.dateWatched.formatted(date: .long, time: .omitted))"
                            + (entry.rating.map { ", rated \($0.formatted()) stars" } ?? ""))
        .accessibilityHint("Opens the movie")
    }
}
