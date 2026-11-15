//
//  Filmstack
//

import Foundation
import Testing
@testable import Filmstack

/// Statistics calculations: date grouping, averages, ties, recap facts,
/// cinema personality and achievement thresholds.
@MainActor
struct WatchedStatsTests {

    /// A fixed calendar and "now", so results don't depend on the machine.
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Stockholm")!
        return calendar
    }()
    private var now: Date { date(2026, 11, 15, 12) }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 20) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func entry(_ title: String, _ date: Date, rating: Double? = nil, genres: [String] = [],
                       director: String? = nil, moods: [String] = []) -> WatchedEntry {
        WatchedEntry(id: UUID(), title: title, dateWatched: date, rating: rating,
                     genres: genres, director: director, moods: moods)
    }

    private func stats(_ entries: [WatchedEntry]) -> WatchedStats {
        WatchedStats(entries: entries, calendar: calendar, now: now)
    }

    // MARK: - Empty

    @Test func emptyHistory() {
        let empty = stats([])
        #expect(empty.isEmpty)
        #expect(empty.months.isEmpty)
        #expect(empty.best(.month) == nil)
        #expect(empty.average(.month) == 0)
        #expect(empty.recapYear == nil)
        #expect(empty.achievements.isEmpty)
    }

    // MARK: - Date grouping

    @Test func monthsIncludeGapsThroughTheCurrentMonth() {
        let result = stats([
            entry("A", date(2026, 7, 31, 23)),   // late on the last day of July
            entry("B", date(2026, 8, 1, 0)),     // midnight, first of August
            entry("C", date(2026, 9, 10)),
        ])
        #expect(result.months.map(\.count) == [1, 1, 1, 0, 0])  // Jul…Nov
        #expect(result.total == 3)
        #expect(result.months.reduce(0) { $0 + $1.count } == result.total)
        #expect(abs(result.average(.month) - 0.6) < 1e-9)
        #expect(result.years.map(\.count) == [3])
        #expect(result.entries(in: result.start(of: date(2026, 8, 5), .month), .month).map(\.title) == ["B"])
    }

    @Test func busiestPeriodTiesPreferTheMostRecent() {
        let result = stats([entry("A", date(2026, 7, 1)), entry("B", date(2026, 9, 1))])
        #expect(result.best(.month)?.start == result.start(of: date(2026, 9, 1), .month))
        #expect(result.latestActive(.month) == result.start(of: date(2026, 9, 1), .month))
    }

    // MARK: - Year scope

    @Test func pastYearCoversJanuaryToDecember() {
        let all = stats([entry("A", date(2025, 3, 5)), entry("B", date(2025, 3, 9)), entry("C", date(2026, 2, 1))])
        let year = all.scoped(toYear: 2025)
        #expect(year.total == 2)
        #expect(year.months.count == 12)
        #expect(year.months.first?.start == year.start(of: date(2025, 1, 1), .month))
        #expect(year.months.map(\.count).reduce(0, +) == 2)
        #expect(abs(year.average(.month) - 2.0 / 12) < 1e-9)
        #expect(year.best(.month)?.count == 2)
    }

    @Test func currentYearStopsAtTheCurrentMonth() {
        let year = stats([entry("A", date(2026, 2, 1))]).scoped(toYear: 2026)
        #expect(year.months.count == 11)  // January through November
        #expect(year.latestActive(.month) == year.start(of: date(2026, 2, 1), .month))
    }

    @Test func watchedYearsAreMostRecentFirst() {
        let all = stats([entry("A", date(2024, 6, 1)), entry("B", date(2026, 1, 1)), entry("C", date(2024, 7, 1))])
        #expect(all.watchedYears == [2026, 2024])
    }

    @Test func scopedAchievementsOnlyCountThatYear() {
        let all = stats((1...8).map { entry("m\($0)", date(2025, 7, $0), rating: 5) })
        #expect(all.scoped(toYear: 2025).achievements.map(\.kind) == [.marathon, .perfectScore])
        #expect(all.scoped(toYear: 2026).achievements.isEmpty)
    }

    // MARK: - Recap facts

    private var busyYear: WatchedStats {
        var entries = (1...8).map {
            entry("July \($0)", date(2026, 7, $0), rating: 3.5, genres: ["Action", "Thriller"], director: "Mann")
        }
        entries.append(entry("Best", date(2026, 3, 2), rating: 5, genres: ["Drama"], director: "Wenders",
                             moods: ["cozy"]))
        entries.append(entry("Also Five", date(2026, 2, 2), rating: 5, genres: ["Drama"]))
        entries.append(entry("Last Year", date(2025, 5, 5), rating: 4, genres: ["Comedy"]))
        return stats(entries)
    }

    @Test func recapFactsAgreeWithTheChart() {
        let result = busyYear
        let facts = result.facts(forYear: 2026)
        #expect(facts.count == 10)
        #expect(facts.count == result.count(inYear: 2026))
        #expect(facts.busiestMonth?.count == 8)
        #expect(facts.busiestMonth == result.best(.month))
        #expect(facts.favoriteGenre == .init(name: "Action", count: 8))
        #expect(facts.topDirector == .init(name: "Mann", count: 8))
        #expect(facts.genreCount == 3)
        #expect(facts.activeMonths == 3)
        #expect(facts.ratedCount == 10)
        #expect(abs((facts.averageRating ?? 0) - 3.8) < 1e-9)
        #expect(result.recapYear == 2026)
    }

    @Test func equallyRatedMoviesPreferTheMostRecentlyWatched() {
        #expect(busyYear.facts(forYear: 2026).topRated?.title == "Best")
    }

    @Test func recapFallsBackToTheLastYearWithEnoughMovies() {
        let result = stats([
            entry("x", date(2025, 1, 1), genres: ["Romance"], director: "Solo"),
            entry("y", date(2025, 2, 1), genres: ["Romance"]),
            entry("z", date(2025, 3, 1), genres: ["Romance"]),
            entry("w", date(2026, 1, 1)),
        ])
        #expect(result.recapYear == 2025)
        let facts = result.facts(forYear: 2025)
        #expect(facts.topDirector == nil)       // one movie isn't a pattern
        #expect(facts.topRated == nil)          // nothing rated
        #expect(facts.averageRating == nil)
    }

    @Test func factsSignatureChangesWithTheFacts() {
        let year = busyYear  // the same movies (and IDs) throughout
        let before = year.facts(forYear: 2026)
        let after = stats(year.entries + [entry("New", date(2026, 10, 1), genres: ["Drama"])])
            .facts(forYear: 2026)
        #expect(before.signature != after.signature)
        #expect(before.signature == stats(year.entries).facts(forYear: 2026).signature)
    }

    // MARK: - Personality

    @Test func clearGenrePatternGivesAPersonality() {
        #expect(busyYear.personality(forYear: 2026)?.title == "The Thrill Seeker")
    }

    @Test func noPersonalityWithoutEnoughMovies() {
        let result = stats((1...4).map { entry("m\($0)", date(2026, $0, 1), genres: ["Romance"]) })
        #expect(result.personality(forYear: 2026) == nil)
    }

    @Test func wideSpreadMakesAFilmBuff() {
        let genres = ["Action", "Comedy", "Drama", "Horror", "Romance", "Western", "War", "Music", "Mystery", "History"]
        let result = stats(genres.enumerated().map {
            entry("m\($0.offset)", date(2026, $0.offset + 1, 3), genres: [$0.element])
        })
        #expect(result.personality(forYear: 2026)?.title == "The Film Buff")
        #expect(result.achievements.map(\.kind) == [.genreExplorer])
    }

    // MARK: - Achievements

    @Test func achievementsFromRealData() {
        let achievements = busyYear.achievements
        #expect(achievements.map(\.kind) == [.marathon, .perfectScore])
        #expect(achievements.first?.subtitle.hasPrefix("8 movies") == true)
    }

    @Test func thresholdsAreExact() {
        var june = (1...7).map { entry("s\($0)", date(2026, 6, $0), rating: 4.5) }
        #expect(stats(june).achievements.isEmpty)  // 7 in a month, best rating 4.5

        june.append(entry("s8", date(2026, 6, 30, 23)))
        #expect(stats(june).achievements.map(\.kind) == [.marathon])
    }
}

/// The recap's AI text is checked so it can't contradict the statistics.
@MainActor
struct YearRecapTextTests {

    @Test func summaryDropsSentencesWithNumbers() {
        let cleaned = YearSummarizer.cleanSummary(
            "You watched 15 movies. Dramas ruled your year. In July you went big. A third sentence.")
        #expect(cleaned == "Dramas ruled your year. In July you went big.")
    }

    @Test func summaryWithOnlyNumbersIsDropped() {
        #expect(YearSummarizer.cleanSummary("You watched 15 movies.") == nil)
    }

    @Test func headlineIsTrimmed() {
        #expect(YearSummarizer.cleanHeadline("  \"The Year of the Slow Burn.\" ") == "The Year of the Slow Burn")
    }

    @Test func headlineWithANumberFallsBack() {
        #expect(YearSummarizer.cleanHeadline("Your 15-Movie Year") == "Your Year in Movies")
    }
}

/// The developer-only Letterboxd diary import's CSV parsing.
@MainActor
struct LetterboxdDiaryImportTests {

    @Test func parsesTheLetterboxdExportFormat() {
        let csv = """
        Date,Name,Year,Letterboxd URI,Rating,Rewatch,Tags,Watched Date
        2025-01-03,"Crouching Tiger, Hidden Dragon",2000,https://boxd.it/a,4.5,,,2024-12-30
        2025-02-01,"The ""Best"" Movie",2019,https://boxd.it/b,,Yes,,2025-02-01
        2025-02-02,No Watched Date,2019,https://boxd.it/c,3,,,
        """
        let rows = LetterboxdDiaryImport.parse(csv)
        #expect(rows.count == 3)
        #expect(rows[0].title == "Crouching Tiger, Hidden Dragon")
        #expect(rows[0].year == 2000)
        #expect(rows[0].rating == 4.5)
        #expect(rows[0].watched == DateComponents(year: 2024, month: 12, day: 30))  // the Watched Date column
        #expect(rows[1].title == "The \"Best\" Movie")
        #expect(rows[1].rating == nil)
        #expect(rows[2].watched == DateComponents(year: 2025, month: 2, day: 2))  // falls back to Date
    }
}

