//
//  Filmstack
//

#if DEBUG

import Foundation
import SwiftData

/// Sample library used for previews and (optionally) first-run demo data.
enum SampleMovies {

    @MainActor
    static func seed(into context: ModelContext) {
        for (index, movie) in makeMovies().enumerated() {
            if movie.status == .queued {
                movie.queuePosition = index
            }
            context.insert(movie)
        }
        try? context.save()
    }

    @MainActor
    static func makeMovies() -> [Movie] {
        [
            Movie(
                title: "Dune: Part Two",
                tmdbID: 693134,
                releaseYear: 2024,
                overview: "Paul Atreides unites with Chani and the Fremen while on a warpath "
                    + "of revenge against the conspirators who destroyed his family.",
                posterPath: "/czembW0Rk1Ke7lCJGahbOhdCuhV.jpg",
                runtimeMinutes: 166,
                genres: ["Sci-Fi", "Adventure"],
                userNotes: "Big screen if possible.",
                streamingLocation: "Max",
                status: .queued
            ),
            Movie(
                title: "Perfect Days",
                tmdbID: 976893,
                releaseYear: 2023,
                overview: "A janitor who cleans public toilets in Tokyo finds beauty in his "
                    + "quiet, structured daily routine.",
                runtimeMinutes: 123,
                genres: ["Drama"],
                userNotes: "Heard a lot of great things.",
                status: .queued
            ),
            Movie(
                title: "The Zone of Interest",
                tmdbID: 467244,
                releaseYear: 2023,
                overview: "The commandant of Auschwitz and his wife strive to build a dream "
                    + "life for their family next to the camp.",
                runtimeMinutes: 106,
                genres: ["Drama", "History"],
                userNotes: "Academy Award winner.",
                status: .queued
            ),
            Movie(
                title: "Heat",
                tmdbID: 949,
                releaseYear: 1995,
                overview: "A group of high-end professional thieves start to feel the heat from "
                    + "the LAPD when they unknowingly leave a clue at their latest heist.",
                runtimeMinutes: 170,
                genres: ["Crime", "Drama"],
                userNotes: "Al Pacino and Robert De Niro.",
                status: .queued
            ),
            Movie(
                title: "Spirited Away",
                tmdbID: 129,
                releaseYear: 2001,
                overview: "A young girl wanders into a world ruled by gods, witches and spirits, "
                    + "where humans are changed into beasts.",
                runtimeMinutes: 125,
                genres: ["Animation", "Fantasy"],
                userNotes: "Miyazaki classic.",
                status: .queued
            ),
            Movie(
                title: "No Country for Old Men",
                tmdbID: 6977,
                releaseYear: 2007,
                overview: "Violence and mayhem ensue after a hunter stumbles upon a drug deal "
                    + "gone wrong and more than two million dollars in cash.",
                runtimeMinutes: 122,
                genres: ["Crime", "Thriller"],
                userNotes: "Coen brothers.",
                status: .maybeLater
            ),
            Movie(
                title: "In the Mood for Love",
                tmdbID: 843,
                releaseYear: 2000,
                overview: "Two neighbours form a strong bond after both suspect extramarital "
                    + "activities of their spouses.",
                runtimeMinutes: 98,
                genres: ["Drama", "Romance"],
                status: .watched,
                dateWatched: Date(timeIntervalSinceNow: -60 * 60 * 24 * 9)
            ),
            Movie(
                title: "Parasite",
                tmdbID: 496243,
                releaseYear: 2019,
                overview: "All unemployed, Ki-taek's family takes peculiar interest in the "
                    + "wealthy and glamorous Parks for their livelihood until they get entangled "
                    + "in an unexpected incident.",
                runtimeMinutes: 133,
                genres: ["Comedy", "Thriller", "Drama"],
                rating: 5,
                status: .watched,
                dateWatched: Date(timeIntervalSinceNow: -60 * 60 * 24 * 30)
            )
        ]
    }
}

#endif
