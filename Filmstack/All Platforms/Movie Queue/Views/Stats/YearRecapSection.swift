//
//  Filmstack
//

import SwiftUI

/// The year in movies: a headline written by Apple Intelligence (when it's
/// available) over highlights taken straight from the statistics, with more
/// insights and a cinema personality when expanded.
struct YearRecapSection: View {

    let stats: WatchedStats
    let facts: WatchedStats.YearFacts
    let personality: WatchedStats.Personality?
    /// The written headline and summary, shared with the share card.
    @Binding var written: YearSummarizer.Written?
    let movie: (UUID) -> Movie?
    let onOpen: (UUID) -> Void

    @State private var isWriting = false
    @State private var writeError: String?
    @State private var isExpanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var yearText: String { String(facts.year) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            highlights
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    if let personality { PersonalityCard(personality: personality) }
                    moreInsights
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            if hasMore {
                Button {
                    withAnimation(reduceMotion ? nil : .smooth(duration: 0.35)) { isExpanded.toggle() }
                } label: {
                    Label(isExpanded ? "Show Less" : "Show More",
                          systemImage: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Palette.accentBright)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .clipped()
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 0.24, green: 0.14, blue: 0.40), Palette.elevated],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Palette.accentBright.opacity(0.18))
        }
        .onAppear {
            if written == nil { written = YearSummarizer.cached(for: facts) }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Your \(yearText) Recap")
                    .font(.caption.weight(.bold))
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.accentBright)
                Spacer()
                if isWriting {
                    ProgressView().controlSize(.small)
                } else if written != nil, FilmstackAI.isAvailable {
                    Button("Rewrite", systemImage: "arrow.clockwise", action: write)
                        .labelStyle(.iconOnly)
                        .foregroundStyle(Palette.textSecondary)
                        .buttonStyle(.plain)
                        .frame(minWidth: 44, minHeight: 44, alignment: .trailing)
                        .accessibilityLabel("Rewrite recap")
                }
            }
            Text(written?.headline ?? String(localized: "Your \(yearText) in Movies"))
                .font(.system(.title, design: .rounded, weight: .bold))
                .foregroundStyle(Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
            Text(countCaption)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Palette.textSecondary)
            if let summary = written?.summary {
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(Palette.textPrimary.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            } else if written == nil, FilmstackAI.isAvailable, !isWriting {
                Button("Write My Recap", systemImage: "sparkles", action: write)
                    .buttonStyle(.filmGlass)
                    .padding(.top, 4)
            }
            if let writeError {
                Text(writeError)
                    .font(.footnote)
                    .foregroundStyle(Palette.textSecondary)
            }
        }
        .animation(reduceMotion ? nil : .smooth(duration: 0.3), value: written)
    }

    /// "15 movies in 7 months".
    private var countCaption: String {
        let movies = facts.count == 1 ? String(localized: "1 movie") : String(localized: "\(facts.count) movies")
        let months = facts.activeMonths == 1
            ? String(localized: "1 month") : String(localized: "\(facts.activeMonths) months")
        return String(localized: "\(movies) in \(months)")
    }

    private func write() {
        guard !isWriting else { return }
        isWriting = true
        writeError = nil
        let facts = facts
        let entries = stats.entries.filter { stats.calendar.component(.year, from: $0.dateWatched) == facts.year }
        Task {
            defer { isWriting = false }
            do {
                let result = try await YearSummarizer.write(facts: facts, entries: entries)
                YearSummarizer.save(result, year: facts.year)
                written = result
            } catch is CancellationError {
            } catch {
                writeError = FilmstackAI.message(for: error)
            }
        }
    }

    // MARK: - Highlights

    @ViewBuilder private var highlights: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
            if let genre = facts.favoriteGenre {
                insightTile("Favorite Genre", value: genre.name, symbol: "theatermasks.fill",
                            detail: genre.count == 1 ? "1 movie" : "\(genre.count) movies")
            }
            if let month = facts.busiestMonth {
                insightTile("Busiest Month", value: month.start.formatted(.dateTime.month(.wide)),
                            symbol: "calendar",
                            detail: month.count == 1 ? "1 movie" : "\(month.count) movies")
            }
        }
        if let top = facts.topRated {
            topRatedTile(top)
        }
    }

    private func topRatedTile(_ top: WatchedEntry) -> some View {
        Button { onOpen(top.id) } label: {
            HStack(spacing: 14) {
                if let movie = movie(top.id) {
                    PosterView(movie: movie, size: .thumbnail, cornerRadius: 6)
                        .frame(width: 54)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Label("Highest Rated", systemImage: "star.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Palette.accentBright)
                    Text(top.title)
                        .font(.headline)
                        .foregroundStyle(Palette.textPrimary)
                        .lineLimit(2)
                    if let rating = top.rating {
                        StarRatingView(rating: .constant(rating), isEditable: false, starSize: 12, spacing: 2)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Palette.textSecondary.opacity(0.6))
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Highest rated: \(top.title)\(top.rating.map { ", \($0.formatted()) stars" } ?? "")")
        .accessibilityHint("Opens the movie")
    }

    // MARK: - More

    /// Extra insights, each only when the data supports it.
    private var extraInsights: [(title: LocalizedStringKey, value: String, symbol: String, detail: String?)] {
        var items: [(LocalizedStringKey, String, String, String?)] = []
        if let director = facts.topDirector {
            items.append(("Top Director", director.name, "megaphone.fill", "\(director.count) movies"))
        }
        if let average = facts.averageRating {
            items.append(("Average Rating", average.formatted(.number.precision(.fractionLength(1))),
                          "star.leadinghalf.filled",
                          facts.ratedCount == 1 ? "from 1 rating" : "from \(facts.ratedCount) ratings"))
        }
        if let mood = facts.topMood {
            items.append(("Top Mood", Mood.title(for: mood.name), "face.smiling",
                          mood.count == 1 ? "1 movie" : "\(mood.count) movies"))
        }
        if facts.genreCount > 1 {
            items.append(("Genres Explored", "\(facts.genreCount)", "square.grid.3x3.fill", nil))
        }
        return items
    }

    private var hasMore: Bool { personality != nil || !extraInsights.isEmpty }

    private var moreInsights: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
            ForEach(Array(extraInsights.enumerated()), id: \.offset) { _, item in
                insightTile(item.title, value: item.value, symbol: item.symbol, detail: item.detail)
            }
        }
    }

    private func insightTile(_ title: LocalizedStringKey, value: String, symbol: String,
                             detail: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Palette.accentBright)
            Text(value)
                .font(.headline)
                .foregroundStyle(Palette.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Palette.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .topLeading)
        .padding(12)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// The cinema personality, when the year's genres show a clear pattern.
struct PersonalityCard: View {
    let personality: WatchedStats.Personality

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: personality.symbol)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(LinearGradient(colors: [Palette.accentBright, Palette.accent],
                                           startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Cinema Personality")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Palette.accentBright)
                Text(personality.title)
                    .font(.headline)
                    .foregroundStyle(Palette.textPrimary)
                Text(personality.description)
                    .font(.subheadline)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Palette.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
