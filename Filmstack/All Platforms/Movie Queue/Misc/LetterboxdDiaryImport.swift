//
//  Filmstack
//

import Foundation
import SwiftData

/// Imports a Letterboxd diary CSV (the `diary.csv` in Letterboxd's data
/// export) as watched movies.
///
/// Each row is looked up on TMDB for its details and poster, then added as
/// watched on its diary date with its rating. Rows already in the library
/// (same TMDB movie watched on the same day) are skipped, so running it
/// twice is harmless. Movies are saved through SwiftData like any other add,
/// so they sync to the other devices.
enum LetterboxdDiaryImport {

    struct Row: Equatable {
        let title: String
        let year: Int?
        let watched: DateComponents
        let rating: Double?
        let letterboxdURI: String?
    }

    struct Summary {
        var added: [String] = []
        var skipped = 0
        var notFound: [String] = []
    }

    // MARK: - Parsing

    /// Rows from a Letterboxd diary CSV. Uses the "Watched Date" column, or
    /// the logged "Date" when that's empty; rows without either are left out.
    static func parse(_ text: String) -> [Row] {
        let records = csvRecords(text)
        guard let header = records.first?.map({ $0.trimmingCharacters(in: .whitespaces).lowercased() }) else {
            return []
        }
        func column(_ name: String) -> Int? { header.firstIndex(of: name) }
        guard let nameColumn = column("name") else { return [] }
        let watchedColumn = column("watched date")
        let loggedColumn = column("date")
        let yearColumn = column("year")
        let ratingColumn = column("rating")
        let uriColumn = column("letterboxd uri")

        return records.dropFirst().compactMap { fields in
            func field(_ index: Int?) -> String? {
                guard let index, fields.indices.contains(index) else { return nil }
                let value = fields[index].trimmingCharacters(in: .whitespaces)
                return value.isEmpty ? nil : value
            }
            guard let title = field(nameColumn),
                  let date = (field(watchedColumn) ?? field(loggedColumn)).flatMap(dateComponents)
            else { return nil }
            return Row(title: title, year: field(yearColumn).flatMap(Int.init), watched: date,
                       rating: field(ratingColumn).flatMap(Double.init), letterboxdURI: field(uriColumn))
        }
    }

    /// "2024-06-30" → year, month, day.
    private static func dateComponents(_ text: String) -> DateComponents? {
        let parts = text.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return DateComponents(year: parts[0], month: parts[1], day: parts[2])
    }

    /// Splits CSV into records of fields, handling quoted fields with commas,
    /// doubled quotes and line breaks.
    static func csvRecords(_ text: String) -> [[String]] {
        var records: [[String]] = []
        var record: [String] = []
        var field = ""
        var inQuotes = false
        var iterator = text.makeIterator()
        var pending: Character?

        while let char = pending ?? iterator.next() {
            pending = nil
            if inQuotes {
                if char == "\"" {
                    if let next = iterator.next() {
                        if next == "\"" { field.append("\"") } else { inQuotes = false; pending = next }
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(char)
                }
            } else {
                switch char {
                case "\"": inQuotes = true
                case ",": record.append(field); field = ""
                case "\n", "\r\n", "\r":
                    record.append(field); field = ""
                    if !(record.count == 1 && record[0].isEmpty) { records.append(record) }
                    record = []
                default: field.append(char)
                }
            }
        }
        if !field.isEmpty || !record.isEmpty {
            record.append(field)
            records.append(record)
        }
        return records
    }

    // MARK: - Import

    /// Imports the rows one at a time, calling `progress` after each.
    @MainActor
    static func run(_ rows: [Row], context: ModelContext, client: any MovieAPIClient, region: String?,
                    progress: (Int) -> Void) async throws -> Summary {
        var summary = Summary()
        let calendar = Calendar.current
        let existing = (try? context.fetch(FetchDescriptor<Movie>())) ?? []

        for (index, row) in rows.enumerated() {
            try Task.checkCancellation()
            defer { progress(index + 1) }

            // Midday local time on the diary date, clear of time zone edges.
            var components = row.watched
            components.hour = 12
            guard let watchedDate = calendar.date(from: components) else { continue }

            let results = try await client.searchMovies(query: row.title)
            let match = results.first { $0.releaseYear == row.year && $0.title.caseInsensitiveCompare(row.title) == .orderedSame }
                ?? results.first { $0.releaseYear == row.year }
                ?? (row.year == nil ? results.first : nil)
            guard let match else {
                summary.notFound.append(row.year.map { "\(row.title) (\($0))" } ?? row.title)
                continue
            }

            let alreadyThere = existing.contains { movie in
                movie.tmdbID == match.tmdbID && movie.status == .watched
                    && movie.dateWatched.map { calendar.isDate($0, inSameDayAs: watchedDate) } == true
            }
            if alreadyThere {
                summary.skipped += 1
                continue
            }

            let details = try await client.fetchMovieDetails(tmdbID: match.tmdbID, region: region)
            let movie = Movie(details: details, source: "Letterboxd", status: .watched)
            movie.dateWatched = watchedDate
            movie.dateAdded = watchedDate
            movie.userRating = row.rating
            movie.letterboxdURLString = row.letterboxdURI
            MovieActions.add(movie, in: context)
            summary.added.append(details.title)

            // Stay well inside TMDB's rate limit (two requests per row).
            try await Task.sleep(for: .milliseconds(300))
        }
        return summary
    }
}
