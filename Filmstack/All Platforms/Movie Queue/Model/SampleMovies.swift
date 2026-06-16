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
                director: "Denis Villeneuve",
                cast: ["Timothée Chalamet", "Zendaya", "Rebecca Ferguson", "Josh Brolin",
                       "Austin Butler", "Florence Pugh", "Javier Bardem"],
                tmdbRating: 8.2,
                imdbID: "tt15239678",
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
                director: "Wim Wenders",
                cast: ["Kōji Yakusho", "Tokio Emoto", "Arisa Nakano", "Aoi Yamada"],
                tmdbRating: 7.7,
                imdbID: "tt27503384",
                userNotes: "Heard a lot of great things.",
                status: .queued
            ),
            Movie(
                title: "The Zone of Interest",
                tmdbID: 467244,
                releaseYear: 2023,
                overview: "The commandant of Auschwitz and his wife strive to build a dream "
                    + "life for their family next to the camp.",
                posterPath: "/hUu9zyZmDd8VZegKi1iK1Vk0RYS.jpg",
                runtimeMinutes: 106,
                genres: ["Drama", "History"],
                director: "Jonathan Glazer",
                cast: ["Christian Friedel", "Sandra Hüller", "Medusa Knopf"],
                tmdbRating: 7.4,
                imdbID: "tt7160372",
                userNotes: "Academy Award winner.",
                status: .queued
            ),
            Movie(
                title: "Heat",
                tmdbID: 949,
                releaseYear: 1995,
                overview: "A group of high-end professional thieves start to feel the heat from "
                    + "the LAPD when they unknowingly leave a clue at their latest heist.",
                posterPath: "/rrBuGu0Pjq7Y2BWSI6teGfZzviY.jpg",
                runtimeMinutes: 170,
                genres: ["Crime", "Drama"],
                director: "Michael Mann",
                cast: ["Al Pacino", "Robert De Niro", "Val Kilmer", "Jon Voight"],
                tmdbRating: 7.9,
                imdbID: "tt0113277",
                userNotes: "Al Pacino and Robert De Niro.",
                status: .queued
            ),
            Movie(
                title: "Spirited Away",
                tmdbID: 129,
                releaseYear: 2001,
                overview: "A young girl wanders into a world ruled by gods, witches and spirits, "
                    + "where humans are changed into beasts.",
                posterPath: "/39wmItIWsg5sZMyRUHLkWBcuVCM.jpg",
                runtimeMinutes: 125,
                genres: ["Animation", "Fantasy"],
                director: "Hayao Miyazaki",
                cast: ["Rumi Hiiragi", "Miyu Irino", "Mari Natsuki", "Takashi Naitō"],
                tmdbRating: 8.5,
                imdbID: "tt0245429",
                userNotes: "Miyazaki classic.",
                status: .queued
            ),
            Movie(
                title: "No Country for Old Men",
                tmdbID: 6977,
                releaseYear: 2007,
                overview: "Violence and mayhem ensue after a hunter stumbles upon a drug deal "
                    + "gone wrong and more than two million dollars in cash.",
                posterPath: "/bj1v6YKF8yHqA489VFfnQvOJpnc.jpg",
                runtimeMinutes: 122,
                genres: ["Crime", "Thriller"],
                director: "Joel Coen, Ethan Coen",
                cast: ["Tommy Lee Jones", "Javier Bardem", "Josh Brolin", "Woody Harrelson"],
                tmdbRating: 8.1,
                imdbID: "tt0477348",
                userNotes: "Coen brothers.",
                status: .maybeLater
            ),
            Movie(
                title: "In the Mood for Love",
                tmdbID: 843,
                releaseYear: 2000,
                overview: "Two neighbours form a strong bond after both suspect extramarital "
                    + "activities of their spouses.",
                posterPath: "/iYypPT4bhqXfq1b6EnmxvRt6b2Y.jpg",
                runtimeMinutes: 98,
                genres: ["Drama", "Romance"],
                director: "Wong Kar-wai",
                cast: ["Tony Leung Chiu-wai", "Maggie Cheung", "Rebecca Pan"],
                tmdbRating: 8.1,
                imdbID: "tt0118694",
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
                posterPath: "/7IiTTgloJzvGI1TAYymCfbfl3vT.jpg",
                runtimeMinutes: 133,
                genres: ["Comedy", "Thriller", "Drama"],
                director: "Bong Joon-ho",
                cast: ["Song Kang-ho", "Lee Sun-kyun", "Cho Yeo-jeong", "Choi Woo-shik"],
                tmdbRating: 8.5,
                imdbID: "tt6751668",
                rating: 5,
                status: .watched,
                dateWatched: Date(timeIntervalSinceNow: -60 * 60 * 24 * 30)
            )
        ]
    }
}

#endif
