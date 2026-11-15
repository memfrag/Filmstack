//
//  Filmstack
//

import Foundation

/// One watched movie, reduced to what the statistics need. Plain values, so
/// the statistics can be computed (and tested) without SwiftData.
nonisolated struct WatchedEntry: Sendable, Hashable {
    let id: UUID
    let title: String
    let dateWatched: Date
    let rating: Double?
    let genres: [String]
    let director: String?
    let moods: [String]
}

/// Every number on the Statistics screen, computed once from the watched
/// movies so the hero, recap, achievements, chart and share image all agree.
///
/// Ties are broken deterministically: busiest/best periods prefer the most
/// recent one, rankings by name prefer alphabetical order, and equally rated
/// movies prefer the most recently watched.
nonisolated struct WatchedStats: Sendable {

    /// Chart and average granularity.
    enum Granularity: Sendable {
        case month, year

        var component: Calendar.Component {
            switch self {
            case .month: .month
            case .year: .year
            }
        }
    }

    struct PeriodCount: Identifiable, Hashable, Sendable {
        let start: Date
        let count: Int
        var id: Date { start }
    }

    struct Ranked: Hashable, Sendable {
        let name: String
        let count: Int
    }

    /// Movies with a watch date, most recent first.
    let entries: [WatchedEntry]
    let calendar: Calendar
    let now: Date

    /// Per month / per year, including empty periods: from the first watched
    /// period through the current one, or across `span` when there is one.
    let months: [PeriodCount]
    let years: [PeriodCount]

    /// The stretch of time these statistics cover, when limited to one
    /// (a single year); nil for everything.
    let span: DateInterval?

    init(entries: [WatchedEntry], calendar: Calendar = .current, now: Date = Date(),
         span: DateInterval? = nil) {
        let entries = span.map { span in entries.filter { span.contains($0.dateWatched) } } ?? entries
        self.entries = entries.sorted { lhs, rhs in
            lhs.dateWatched != rhs.dateWatched ? lhs.dateWatched > rhs.dateWatched : lhs.title < rhs.title
        }
        self.calendar = calendar
        self.now = now
        self.span = span
        self.months = Self.counts(entries, .month, calendar: calendar, now: now, span: span)
        self.years = Self.counts(entries, .year, calendar: calendar, now: now, span: span)
    }

    /// Years with anything watched, most recent first.
    var watchedYears: [Int] {
        Array(Set(entries.map { calendar.component(.year, from: $0.dateWatched) })).sorted(by: >)
    }

    /// The same statistics for one calendar year: its months run January to
    /// December, or to the current month for the current year.
    func scoped(toYear year: Int) -> WatchedStats {
        let start = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) ?? now
        let end = calendar.date(byAdding: .year, value: 1, to: start) ?? now
        return WatchedStats(entries: entries, calendar: calendar, now: now,
                            span: DateInterval(start: start, end: end))
    }

    // MARK: - Periods

    func counts(_ granularity: Granularity) -> [PeriodCount] {
        granularity == .month ? months : years
    }

    func start(of date: Date, _ granularity: Granularity) -> Date {
        calendar.dateInterval(of: granularity.component, for: date)?.start ?? date
    }

    var total: Int { entries.count }
    var isEmpty: Bool { entries.isEmpty }

    var currentYear: Int { calendar.component(.year, from: now) }

    func count(inYear year: Int) -> Int {
        entries.filter { calendar.component(.year, from: $0.dateWatched) == year }.count
    }

    /// Average per month or year across the whole span shown in the chart.
    func average(_ granularity: Granularity) -> Double {
        let periods = counts(granularity)
        guard !periods.isEmpty else { return 0 }
        return Double(total) / Double(periods.count)
    }

    /// The period with the most movies; the most recent one on a tie.
    func best(_ granularity: Granularity) -> PeriodCount? {
        Self.busiest(counts(granularity))
    }

    /// The most recent period with anything watched.
    func latestActive(_ granularity: Granularity) -> Date? {
        counts(granularity).last { $0.count > 0 }?.start
    }

    /// Movies watched in the period starting at `start`, most recent first.
    func entries(in start: Date, _ granularity: Granularity) -> [WatchedEntry] {
        entries.filter {
            calendar.isDate($0.dateWatched, equalTo: start, toGranularity: granularity.component)
        }
    }

    // MARK: - Year recap facts

    /// The authoritative facts for a year's recap. The AI only phrases a
    /// headline around these; every number shown comes from here.
    struct YearFacts: Hashable, Sendable {
        let year: Int
        let count: Int
        let favoriteGenre: Ranked?
        let busiestMonth: PeriodCount?
        let topRated: WatchedEntry?
        let topDirector: Ranked?
        let topMood: Ranked?
        let averageRating: Double?
        let ratedCount: Int
        let genreCount: Int
        let activeMonths: Int

        /// Changes when the facts behind a written recap change.
        var signature: String {
            [String(year), String(count), favoriteGenre?.name ?? "",
             topRated?.id.uuidString ?? "", busiestMonth.map { String($0.start.timeIntervalSince1970) } ?? ""]
                .joined(separator: "|")
        }
    }

    /// Minimum movies in a year for a recap.
    static let recapMinimum = 3

    /// The year to recap: this year once it has enough movies, otherwise the
    /// most recent year that does.
    var recapYear: Int? {
        if count(inYear: currentYear) >= Self.recapMinimum { return currentYear }
        return years.reversed()
            .first { $0.count >= Self.recapMinimum }
            .map { calendar.component(.year, from: $0.start) }
    }

    func facts(forYear year: Int) -> YearFacts {
        let watched = entries.filter { calendar.component(.year, from: $0.dateWatched) == year }
        let monthCounts = Dictionary(grouping: watched) { start(of: $0.dateWatched, .month) }
            .map { PeriodCount(start: $0.key, count: $0.value.count) }
        let rated = watched.compactMap(\.rating)
        let genres = Self.ranked(watched.flatMap { Array(Set($0.genres)) })
        let directors = Self.ranked(watched.compactMap(\.director))
        let moods = Self.ranked(watched.flatMap { Array(Set($0.moods)) })

        return YearFacts(
            year: year,
            count: watched.count,
            favoriteGenre: genres.first,
            busiestMonth: Self.busiest(monthCounts),
            topRated: Self.topRated(watched),
            topDirector: directors.first.flatMap { $0.count >= 2 ? $0 : nil },
            topMood: moods.first,
            averageRating: rated.isEmpty ? nil : rated.reduce(0, +) / Double(rated.count),
            ratedCount: rated.count,
            genreCount: genres.count,
            activeMonths: monthCounts.count
        )
    }

    // MARK: - Cinema personality

    struct Personality: Hashable, Sendable {
        let title: String
        let symbol: String
        let description: String
    }

    /// Minimum movies in a year before a personality is assigned.
    static let personalityMinimum = 5

    /// A personality from the year's genres, only when the pattern is clear.
    /// Each rule needs a share of the year's movies to carry one of its
    /// genres; the strongest qualifying rule wins. Without a clear pattern,
    /// a wide spread of genres makes a Film Buff; otherwise there's none.
    func personality(forYear year: Int) -> Personality? {
        let watched = entries.filter { calendar.component(.year, from: $0.dateWatched) == year }
        guard watched.count >= Self.personalityMinimum else { return nil }

        func share(_ genres: Set<String>) -> Double {
            Double(watched.filter { !genres.isDisjoint(with: $0.genres) }.count) / Double(watched.count)
        }

        struct Rule {
            let personality: Personality
            let genres: Set<String>
            let threshold: Double
        }
        let rules = [
            Rule(personality: Personality(title: "The Thrill Seeker", symbol: "bolt.heart.fill",
                                          description: "Action, thrillers and horror keep your pulse up."),
                 genres: ["Action", "Thriller", "Horror"], threshold: 0.5),
            Rule(personality: Personality(title: "The Explorer", symbol: "sparkles",
                                          description: "You're drawn to science fiction, fantasy and adventure."),
                 genres: ["Science Fiction", "Fantasy", "Adventure"], threshold: 0.5),
            Rule(personality: Personality(title: "The Romantic", symbol: "heart.fill",
                                          description: "Love stories and the people in them win you over."),
                 genres: ["Romance"], threshold: 0.4),
            Rule(personality: Personality(title: "The Laugh Seeker", symbol: "face.smiling.inverse",
                                          description: "You pick comedies more than anything else."),
                 genres: ["Comedy"], threshold: 0.5),
            Rule(personality: Personality(title: "The Dramatist", symbol: "theatermasks.fill",
                                          description: "Character-driven dramas are your home ground."),
                 genres: ["Drama"], threshold: 0.6),
        ]

        // How far each rule clears its threshold; the clearest wins (the
        // first listed on a tie).
        var winner: (personality: Personality, margin: Double)?
        for rule in rules {
            let margin = share(rule.genres) - rule.threshold
            if margin >= 0, margin > (winner?.margin ?? -1) {
                winner = (rule.personality, margin)
            }
        }
        if let winner { return winner.personality }

        let genres = Self.ranked(watched.flatMap { Array(Set($0.genres)) })
        if genres.count >= 8, let top = genres.first, Double(top.count) / Double(watched.count) < 0.4 {
            return Personality(title: "The Film Buff", symbol: "film.stack.fill",
                               description: "You range across \(genres.count) genres without settling on one.")
        }
        return nil
    }

    // MARK: - Achievements

    struct Achievement: Identifiable, Hashable, Sendable {
        enum Kind: String, Sendable { case marathon, perfectScore, genreExplorer, sciFi, cinephile, critic }
        let kind: Kind
        let title: String
        let subtitle: String
        let symbol: String
        var id: Kind { kind }
    }

    /// Thresholds, so the rules are stated in one place.
    enum Threshold {
        static let marathonMovies = 8
        static let genreExplorerGenres = 10
        static let sciFiMovies = 5
        static let cinephileMovies = 50
        static let criticRatings = 25
    }

    /// Achievements earned from everything watched, in a fixed order.
    var achievements: [Achievement] {
        var earned: [Achievement] = []

        if let best = best(.month), best.count >= Threshold.marathonMovies {
            earned.append(Achievement(
                kind: .marathon, title: "Movie Marathon",
                subtitle: "\(best.count) movies in \(best.start.formatted(.dateTime.month(.wide).year()))",
                symbol: "flame.fill"))
        }
        if let perfect = entries.first(where: { ($0.rating ?? 0) >= 5 }) {
            earned.append(Achievement(
                kind: .perfectScore, title: "Perfect Score",
                subtitle: "Five stars for \(perfect.title)", symbol: "star.fill"))
        }
        let genreCount = Set(entries.flatMap(\.genres)).count
        if genreCount >= Threshold.genreExplorerGenres {
            earned.append(Achievement(
                kind: .genreExplorer, title: "Genre Explorer",
                subtitle: "\(genreCount) different genres", symbol: "safari.fill"))
        }
        let sciFi = entries.filter { $0.genres.contains("Science Fiction") }.count
        if sciFi >= Threshold.sciFiMovies {
            earned.append(Achievement(
                kind: .sciFi, title: "Sci-Fi Explorer",
                subtitle: "\(sciFi) science fiction movies", symbol: "atom"))
        }
        if total >= Threshold.cinephileMovies {
            earned.append(Achievement(
                kind: .cinephile, title: "Cinephile",
                subtitle: "\(total) movies watched", symbol: "film.stack.fill"))
        }
        let rated = entries.filter { $0.rating != nil }.count
        if rated >= Threshold.criticRatings {
            earned.append(Achievement(
                kind: .critic, title: "Critic",
                subtitle: "\(rated) movies rated", symbol: "text.bubble.fill"))
        }
        return earned
    }

    // MARK: - Helpers

    private static func counts(_ entries: [WatchedEntry], _ granularity: Granularity,
                               calendar: Calendar, now: Date, span: DateInterval?) -> [PeriodCount] {
        func start(_ date: Date) -> Date {
            calendar.dateInterval(of: granularity.component, for: date)?.start ?? date
        }
        let counts = Dictionary(grouping: entries) { start($0.dateWatched) }.mapValues(\.count)
        let first: Date
        let last: Date
        if let span {
            // The whole span, but not past the current period.
            first = start(span.start)
            last = max(first, min(start(now), start(span.end.addingTimeInterval(-1))))
        } else {
            guard let earliest = counts.keys.min() else { return [] }
            first = earliest
            last = max(start(now), counts.keys.max() ?? first)
        }

        var result: [PeriodCount] = []
        var date = first
        while date <= last {
            result.append(PeriodCount(start: date, count: counts[date] ?? 0))
            guard let next = calendar.date(byAdding: granularity.component, value: 1, to: date) else { break }
            date = next
        }
        return result
    }

    /// Highest count first, then name.
    private static func ranked(_ names: [String]) -> [Ranked] {
        Dictionary(grouping: names, by: { $0 })
            .map { Ranked(name: $0.key, count: $0.value.count) }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.name < $1.name }
    }

    /// Most movies; the most recent period on a tie. Nil when all are empty.
    private static func busiest(_ periods: [PeriodCount]) -> PeriodCount? {
        periods
            .filter { $0.count > 0 }
            .max { $0.count != $1.count ? $0.count < $1.count : $0.start < $1.start }
    }

    /// Highest rated; then most recently watched; then title.
    private static func topRated(_ entries: [WatchedEntry]) -> WatchedEntry? {
        entries
            .filter { $0.rating != nil }
            .max { lhs, rhs in
                if lhs.rating != rhs.rating { return (lhs.rating ?? 0) < (rhs.rating ?? 0) }
                if lhs.dateWatched != rhs.dateWatched { return lhs.dateWatched < rhs.dateWatched }
                return lhs.title > rhs.title
            }
    }
}
