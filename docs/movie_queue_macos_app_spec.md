# Movie Queue — macOS App Specification

## 1. Product Summary

Movie Queue is a native macOS app for maintaining a personal queue of movies the user wants to watch.

The app is queue-first: its main job is to answer the question, “What should I watch next?”

The app is:

- Native macOS
- Built with SwiftUI
- Local-first
- Non-commercial
- Distributed outside the Mac App Store
- Intended for personal use and limited sharing with friends
- API-backed using TMDB
- Bring-your-own-api-key
- Poster-enabled
- No backend service
- No user accounts
- No analytics or telemetry

The user can search for movies using TMDB, add them to a prioritized queue, view posters and metadata, reorder the queue, mark movies as watched, and open a related Letterboxd search/page.

---

## 2. Target Platform

### Platform

macOS desktop app.

### Recommended Technology

- Swift
- SwiftUI
- SwiftData or Core Data for local persistence
- URLSession for API requests
- macOS Keychain for TMDB token storage
- AsyncImage or custom image loader for poster display
- Local disk cache for poster images

### Minimum macOS Target

Recommended: macOS 14 or later.

This can be adjusted if broader compatibility is required.

---

## 3. Distribution Model

Movie Queue is distributed outside the Mac App Store.

The app is intended for personal use and limited sharing with friends. It is non-commercial and does not include paid features, subscriptions, ads, analytics, or tracking.

Distribution may happen through:

- A signed and notarized downloadable app
- A private GitHub release
- Direct sharing of a `.dmg` or `.zip`

Recommended distribution requirements:

- Sign the app with a Developer ID certificate
- Notarize the app with Apple
- Do not require a backend service
- Store all user data locally by default
- Store the TMDB credential in macOS Keychain

---

## 4. Non-Goals

The MVP should not include:

- User accounts
- Cloud sync
- iCloud sync
- App Store distribution
- Paid features
- Subscriptions
- Ads
- Social features
- Reviews from other users
- Recommendations
- Automatic streaming availability lookup
- Letterboxd API integration
- Letterboxd scraping
- Bulk TMDB scraping
- Backend proxy server
- Analytics or telemetry

---

## 5. Core User Experience

The app should feel:

- Fast
- Quiet
- Lightweight
- Personal
- Queue-first
- Native to macOS

The primary interaction is managing a prioritized watch queue.

The queue should always be easy to scan, reorder, and act on.

The app should feel like a focused personal utility, not a full media database.

---

## 6. Main Navigation

Use a three-pane macOS layout.

```text
Sidebar          Queue List                 Detail Panel
--------------------------------------------------------
Queue            1. Movie title             Movie details
Watched          2. Movie title             Poster
Maybe Later      3. Movie title             Actions
Settings                                   Letterboxd link
```

### Sidebar Sections

Library:

- Queue
- Watched
- Maybe Later

Filters:

- All
- By Genre
- By Source

Settings:

- General
- TMDB API Key

The sidebar can be simplified for MVP if needed, but Queue and Watched are required.

---

## 7. MVP Feature List

The MVP must include:

1. TMDB API setup using bring-your-own API token
2. Store TMDB token in macOS Keychain
3. Validate TMDB token
4. Search movies through TMDB
5. Show search results with poster thumbnails
6. Add selected TMDB movie to queue
7. Fetch and store movie metadata locally
8. Display movie poster thumbnails in queue
9. Display larger poster in movie detail view
10. Reorder queue using drag and drop
11. Persist queue order locally
12. Mark movie as watched
13. View watched history
14. Edit user-specific movie fields
15. Delete movie
16. Manual add fallback when TMDB is unavailable or no token exists
17. Open movie in Letterboxd using TMDB ID search URL
18. Local search/filter by movie title
19. TMDB attribution in About/Credits

---

## 8. Data Model

### Movie

Persistent local model.

```swift
enum MovieStatus: String, Codable, CaseIterable {
    case queued
    case watched
    case maybeLater
}
```

```swift
struct Movie {
    var id: UUID

    // External metadata
    var tmdbID: Int?
    var title: String
    var originalTitle: String?
    var releaseDate: Date?
    var releaseYear: Int?
    var overview: String?
    var posterPath: String?
    var backdropPath: String?
    var runtimeMinutes: Int?
    var genres: [String]

    // Optional external links
    var letterboxdURL: URL?

    // User-owned fields
    var userNotes: String
    var source: String?
    var streamingLocation: String?
    var rating: Int?

    // Queue state
    var status: MovieStatus
    var queuePosition: Int?
    var dateAdded: Date
    var dateWatched: Date?

    // Timestamps
    var createdAt: Date
    var updatedAt: Date
}
```

### MovieSearchResult

Transient model used for TMDB search results before saving.

```swift
struct MovieSearchResult: Identifiable, Codable {
    var id: Int { tmdbID }
    var tmdbID: Int
    var title: String
    var originalTitle: String?
    var releaseDate: Date?
    var releaseYear: Int?
    var overview: String?
    var posterPath: String?
    var posterThumbnailURL: URL?
}
```

### MovieDetails

Transient model returned after fetching full TMDB movie details.

```swift
struct MovieDetails: Codable {
    var tmdbID: Int
    var title: String
    var originalTitle: String?
    var releaseDate: Date?
    var releaseYear: Int?
    var overview: String?
    var posterPath: String?
    var backdropPath: String?
    var runtimeMinutes: Int?
    var genres: [String]
}
```

---

## 9. TMDB Integration

### Provider

Use TMDB for:

- Movie search
- Movie details
- Poster images
- Basic metadata such as title, release date, overview, runtime, and genres

### Non-Commercial Usage

Movie Queue is a non-commercial app that uses TMDB for metadata and poster images. Users provide their own TMDB API credentials. Credentials are stored only in macOS Keychain and are used only for direct requests from the app to TMDB.

The app must not:

- Resell TMDB data
- Bulk export TMDB data
- Scrape or mirror TMDB
- Provide a commercial API proxy
- Imply TMDB endorsement

### Attribution

The app must include a Credits/About section with this attribution text:

```text
This product uses the TMDB API but is not endorsed or certified by TMDB.
```

The app should also include an approved TMDB logo in the About/Credits area if required by TMDB’s current rules.

### API Key Strategy

The app does not ship with a shared TMDB API key.

Users must provide their own TMDB API Read Access Token to enable movie search and poster lookup.

Use TMDB Read Access Token as a Bearer token:

```http
Authorization: Bearer <token>
```

Avoid putting credentials in query parameters.

### Credential Storage

Store the TMDB token in macOS Keychain.

Requirements:

- Never store the token in UserDefaults
- Never store the token in SwiftData/Core Data
- Never include the token in logs
- Never show the full token again after saving
- Allow the user to replace the token
- Allow the user to delete the token
- Allow the user to test the token
- Movie search is disabled until a valid token exists
- Manual movie entry remains available without a token

Suggested Keychain identifiers:

```swift
let service = "com.yourname.MovieQueue.tmdb"
let account = "tmdb-read-access-token"
```

### API Key Setup Flow

```text
User opens Add Movie
→ App detects no TMDB token
→ App shows API key setup screen
→ User enters TMDB Read Access Token
→ App validates token
→ App saves token to Keychain
→ User can search for movies
```

### API Key Settings UI

```text
Settings
└── Movie Database
    ├── Provider: TMDB
    ├── API Key Status: Configured / Missing / Invalid
    ├── Replace Key
    ├── Delete Key
    └── Test Connection
```

Do not display the full token after saving.

Acceptable display:

```text
TMDB key configured
```

or:

```text
TMDB key configured: ••••••••••••abcd
```

### Token Validation

When the user saves a token:

- Send a lightweight authenticated request to TMDB
- If successful, save the token to Keychain
- If invalid, show an error and do not save

Recommended validation endpoint:

```text
GET /configuration
```

### API Client Protocol

```swift
protocol MovieAPIClient {
    func searchMovies(query: String) async throws -> [MovieSearchResult]
    func fetchMovieDetails(tmdbID: Int) async throws -> MovieDetails
    func posterURL(path: String, size: PosterSize) -> URL?
    func validateToken(_ token: String) async throws -> Bool
}
```

### TMDB Client Sketch

```swift
final class TMDBClient: MovieAPIClient {
    private let keyStore: APIKeyStore

    init(keyStore: APIKeyStore) {
        self.keyStore = keyStore
    }

    func searchMovies(query: String) async throws -> [MovieSearchResult] {
        guard let token = try keyStore.loadTMDBToken() else {
            throw TMDBError.missingAPIKey
        }

        var request = URLRequest(url: searchURL(query: query))
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        // Perform request with URLSession
        // Decode TMDB response
        // Map response to MovieSearchResult
    }

    func fetchMovieDetails(tmdbID: Int) async throws -> MovieDetails {
        guard let token = try keyStore.loadTMDBToken() else {
            throw TMDBError.missingAPIKey
        }

        var request = URLRequest(url: detailsURL(tmdbID: tmdbID))
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        // Perform request with URLSession
        // Decode TMDB response
        // Map response to MovieDetails
    }

    func posterURL(path: String, size: PosterSize) -> URL? {
        // Build URL from TMDB image configuration
        // Fallback to known TMDB image base URL only if configuration is unavailable
    }

    func validateToken(_ token: String) async throws -> Bool {
        // Call GET /configuration with Bearer token
    }
}
```

### API Rate/Request Behavior

The app must:

- Debounce search input by 300–500 ms
- Only search after at least 2 characters
- Cancel stale search requests when query changes
- Avoid bulk scraping or background prefetching
- Respect HTTP 429 responses
- Cache poster images locally
- Cache movie details after adding to queue

---

## 10. Poster Image Handling

### Required Behavior

The app displays:

- Poster thumbnails in search results
- Poster thumbnails in the queue
- Larger poster in the movie detail panel
- Placeholder art when no poster is available

### Storage Strategy

Store metadata in the database:

- `posterPath`
- Optional generated poster URL

Do not store raw image data directly in the main movie database.

Recommended image strategy:

```text
Movie record stores posterPath
Image loader creates poster URL
Poster image is fetched from TMDB
Poster image is cached locally on disk
```

### Poster Sizes

```swift
enum PosterSize {
    case thumbnail
    case queue
    case detail
}
```

Suggested mappings:

- `thumbnail`: small TMDB poster size for search results
- `queue`: small or medium size for queue rows
- `detail`: medium poster size for detail view

Use TMDB image configuration when possible instead of hardcoding image sizes.

### Poster Cache

Requirements:

- Cache poster images by TMDB ID and poster path
- Avoid re-downloading posters unnecessarily
- If a poster fails to load, show placeholder
- Poster loading must not block the queue UI

---

## 11. Letterboxd Linking

The MVP does not use the Letterboxd API.

The app must not scrape Letterboxd.

Each movie detail page includes an “Open in Letterboxd” action.

### Link Resolution Order

When opening Letterboxd:

1. If `movie.letterboxdURL` exists, open it directly
2. Else if `movie.tmdbID` exists, open a Letterboxd TMDB search URL
3. Else fall back to a Letterboxd title search URL

### URL Rules

For TMDB-backed movies:

```text
https://letterboxd.com/search/tmdb:<tmdbID>/
```

For manual movies without a TMDB ID:

```text
https://letterboxd.com/search/<encoded title>/
```

### Implementation Sketch

```swift
func letterboxdURL(for movie: Movie) -> URL? {
    if let url = movie.letterboxdURL {
        return url
    }

    if let tmdbID = movie.tmdbID {
        return URL(string: "https://letterboxd.com/search/tmdb:\(tmdbID)/")
    }

    let allowed = CharacterSet.urlPathAllowed
    let query = movie.title.addingPercentEncoding(withAllowedCharacters: allowed) ?? movie.title
    return URL(string: "https://letterboxd.com/search/\(query)/")
}
```

Button label:

```text
Open in Letterboxd
```

Do not label it “View on Letterboxd” because the MVP may open a search result rather than the exact film page.

---

## 12. Main Screens

## 12.1 Queue Screen

The queue screen is the main screen.

It shows queued movies ordered by `queuePosition`.

Required UI elements:

- Window title: Movie Queue
- Sidebar
- Queue list
- Add Movie button
- Search queue field
- Detail panel for selected movie

Queue header example:

```text
Queue   12 movies
```

Queue row example:

```text
1  [Poster]  Dune: Part Two
             2024 · 2h 46m · Sci-Fi, Adventure
             Big screen if possible.
```

Required row behavior:

- Show queue position
- Show poster thumbnail or placeholder
- Show movie title
- Show release year when available
- Show runtime when available
- Show genres when available
- Show user notes preview when available
- Support drag-and-drop reordering
- Selecting a row opens details in the detail panel

### Queue Empty State

```text
Your movie queue is empty.
Add something you want to watch.
```

---

## 12.2 Add Movie Search Sheet

The add flow is search-first.

```text
Add Movie

Search
[________________________]

Results
------------------------------------------------
[Poster]  Movie Title
          Year
          Short overview
------------------------------------------------
[Poster]  Movie Title
          Year
          Short overview

[Add Manually]
```

### Search Result Row

Each search result shows:

- Poster thumbnail or placeholder
- Title
- Release year
- Short overview

### Search Flow

```text
User clicks Add Movie
→ Search sheet opens
→ User types movie title
→ App searches TMDB after debounce
→ Results appear with poster, title, year, overview
→ User selects a movie
→ App fetches full movie details
→ User can add notes and optional location/source
→ User clicks Add to Queue
→ Movie appears at bottom of queue
```

### Selected Movie Confirmation UI

```text
[Poster]

Dune: Part Two
2024
Runtime: 166 min
Genres: Sci-Fi, Adventure

[Optional notes]
[Where can you watch it?]
[Where did you hear about it?]

[Cancel] [Add to Queue]
```

---

## 12.3 Manual Add Sheet

Manual add remains available without a TMDB token or when a movie cannot be found.

Fields:

- Title, required
- Year, optional
- Notes, optional
- Streaming location, optional
- Source, optional

Manual movies may have no poster.

Manual add should do a soft duplicate check by title and year.

---

## 12.4 Movie Detail Panel

The detail panel shows the selected movie.

Required fields:

- Larger poster or placeholder
- Title
- Release year
- Runtime
- Genres
- Director, optional if available later
- Release date
- Overview
- User notes
- Streaming location
- Date added
- Date watched if watched

Required actions:

- Mark as Watched
- Edit
- Delete
- Move to Top
- Move to Bottom
- Open in Letterboxd

Example layout:

```text
[Large Poster]

Dune: Part Two
2024 · 2h 46m
Sci-Fi, Adventure

Overview
Paul Atreides unites with Chani...

My Notes
Big screen if possible.

Where to Watch
Max

Added
May 23, 2024

[Mark as Watched] [Edit] [...] [Open in Letterboxd]
```

---

## 12.5 Watched Screen

Shows movies with `status = watched`.

Default sort:

- Most recently watched first

Required display:

- Poster thumbnail
- Title
- Release year
- Watched date
- Rating if available

Required behavior:

- User can view details
- User can move movie back to queue
- User can delete movie

---

## 13. Queue Behavior

### Adding a Movie

Default behavior:

- Create movie with `status = queued`
- Assign `queuePosition = max(queuePosition) + 1`
- Set `dateAdded = now`
- Set `createdAt = now`
- Set `updatedAt = now`

Optional UI behavior:

- “Add to Top” assigns position `0` and shifts others down

### Reordering

When the user reorders the queue:

- Update `queuePosition` values
- Keep positions contiguous
- Only queued movies should have active queue positions
- Persist the new order immediately

Example:

```text
Before:
1. Alien
2. Heat
3. Drive

After dragging Drive to top:
1. Drive
2. Alien
3. Heat
```

### Marking Watched

When a movie is marked watched:

```text
status = watched
dateWatched = current date
queuePosition = nil
updatedAt = current date
```

Then renumber the remaining queued movies.

### Moving Watched Movie Back to Queue

When a watched movie is moved back to queue:

```text
status = queued
dateWatched = nil
queuePosition = max(queuePosition) + 1
updatedAt = current date
```

---

## 14. Duplicate Handling

### TMDB Movies

When adding a movie from TMDB:

- If `tmdbID` already exists in the queue, show an error
- If `tmdbID` exists in watched history, ask whether to add it again

Messages:

```text
This movie is already in your queue.
```

```text
You already watched this movie. Add it again?
```

### Manual Movies

For manual entries, perform a soft duplicate check by title and year.

If possible duplicate found:

```text
A similar movie already exists. Add anyway?
```

---

## 15. Local Search and Filtering

The queue screen includes a local search field.

MVP search behavior:

- Search by title
- Search should be local only
- Search should not call TMDB
- Clearing search restores the full queue

Optional later search fields:

- Genre
- Notes
- Streaming location
- Source

---

## 16. Error Handling

The app must handle these states gracefully:

### API and Network

- No API key configured
- Invalid API key
- Deleted or revoked API key
- TMDB service unavailable
- Network unavailable
- Request timed out
- Rate limited with HTTP 429
- No search results
- Movie details unavailable
- Poster unavailable

### Keychain

- Keychain read failure
- Keychain write failure
- Keychain delete failure

### Persistence

- Database save failure
- Database read failure
- Queue reorder persistence failure

### Suggested Messages

```text
Movie search requires a TMDB API key.
```

```text
Your TMDB API key appears to be invalid.
```

```text
Could not read the API key from Keychain.
```

```text
TMDB is currently unavailable. You can still add a movie manually.
```

```text
No movies found.
```

```text
This movie does not have a poster.
```

---

## 17. Privacy Requirements

Movie Queue does not operate a backend service.

The app must not collect:

- Analytics
- Telemetry
- Crash reports without explicit opt-in
- User accounts
- Email addresses
- Usage history

Data storage:

- Movie queue is stored locally on the user’s Mac
- Watched history is stored locally on the user’s Mac
- TMDB token is stored in macOS Keychain
- Poster images are cached locally

Network behavior:

- Movie searches are sent directly from the app to TMDB
- Poster images are loaded directly from TMDB image URLs
- Letterboxd links open in the user’s browser

Onboarding copy:

```text
Movie Queue uses TMDB to search for movies and load posters.

To use movie search, add your own TMDB API Read Access Token. The token is stored securely in your Mac’s Keychain.

This app is for personal, non-commercial use.
```

---

## 18. Architecture

Recommended high-level architecture:

```text
SwiftUI Views
    ↓
View Models / Observable Models
    ↓
Services
    ├── TMDBClient
    ├── APIKeyStore
    ├── PosterImageCache
    └── MovieRepository
    ↓
Persistence
    ├── SwiftData/Core Data
    └── Keychain
```

### Suggested Components

#### MovieRepository

Responsible for local movie persistence.

```swift
protocol MovieRepository {
    func queuedMovies() throws -> [Movie]
    func watchedMovies() throws -> [Movie]
    func addMovie(_ movie: Movie) throws
    func updateMovie(_ movie: Movie) throws
    func deleteMovie(_ movie: Movie) throws
    func reorderQueuedMovies(_ movies: [Movie]) throws
    func markWatched(_ movie: Movie, watchedAt: Date) throws
}
```

#### APIKeyStore

Responsible for Keychain access.

```swift
protocol APIKeyStore {
    func saveTMDBToken(_ token: String) throws
    func loadTMDBToken() throws -> String?
    func deleteTMDBToken() throws
}
```

#### PosterImageCache

Responsible for poster loading and local caching.

```swift
protocol PosterImageCache {
    func imageURL(for movie: Movie, size: PosterSize) -> URL?
    func cachedImage(for movie: Movie, size: PosterSize) async -> Image?
    func clearCache() throws
}
```

---

## 19. First Build Order

Recommended implementation order:

1. Create SwiftUI app shell with three-pane layout
2. Create local `Movie` model
3. Implement local persistence
4. Build queue list UI without API
5. Add manual movie creation
6. Add queue reordering and persistence
7. Add watched state and watched history
8. Implement Keychain-backed `APIKeyStore`
9. Add TMDB token settings screen
10. Implement token validation
11. Implement `TMDBClient.searchMovies`
12. Build Add Movie search sheet
13. Implement `TMDBClient.fetchMovieDetails`
14. Save selected TMDB movie to queue
15. Implement poster URL generation
16. Implement poster thumbnail loading
17. Add local poster cache
18. Build detail panel with larger poster
19. Add Letterboxd link action
20. Add duplicate detection
21. Add error states and empty states
22. Add About/Credits with TMDB attribution
23. Sign and notarize app for direct distribution

---

## 20. Acceptance Criteria

### API Key Setup

- User can open TMDB API key settings
- User can paste a TMDB Read Access Token
- App validates the token before saving
- Valid token is stored in Keychain
- Invalid token is not saved
- User can replace token
- User can delete token
- App never displays the full saved token

### Search for Movie

- User can open Add Movie sheet
- User can type a movie title
- App waits for debounce before searching
- App searches TMDB using Bearer token
- App shows results with poster, title, year, and overview
- User sees a useful error if TMDB is unavailable
- User can manually add a movie if search fails

### Add Movie to Queue

- User can select a TMDB search result
- App fetches movie details
- User can add notes and optional streaming location/source
- App saves movie locally
- Movie appears at bottom of queue
- Queue order persists after app relaunch

### Posters

- Queue rows show poster thumbnails when available
- Detail panel shows larger poster when available
- Missing posters show placeholder art
- Poster loading does not block the UI
- Posters are cached locally

### Reorder Queue

- User can drag movies into a new order
- New order updates visually immediately
- New order persists after closing and reopening the app
- Queue positions remain contiguous

### Mark Watched

- User can mark queued movie as watched
- Movie disappears from active queue
- Movie appears in watched history
- Watched date is recorded
- Remaining queue items are renumbered

### Letterboxd Link

- Movie detail view includes “Open in Letterboxd”
- If movie has a saved Letterboxd URL, app opens it
- Else if movie has a TMDB ID, app opens `https://letterboxd.com/search/tmdb:<tmdbID>/`
- Else app opens Letterboxd title search
- App does not scrape Letterboxd
- App does not require Letterboxd API access

### Privacy

- App has no backend service
- App does not collect analytics
- App does not require an account
- TMDB token is stored only in Keychain
- Movie data is stored locally

---

## 21. Future Enhancements

Possible post-MVP features:

- iCloud sync
- Menu bar quick add
- Share extension from Safari
- Letterboxd import
- CSV import/export
- Tags
- Smart filters
- Random “pick something for me” button
- Watch tonight shortlist
- Runtime-based filtering
- Genre-based filtering
- Better source tracking
- Ratings and review notes
- Trailer links
- Cast/crew detail
- Direct Letterboxd URL discovery through a user-provided URL
- Custom poster override
- Backup/restore

---

## 22. Final Product Principle

Do not let the app become a general movie database.

The app’s central purpose is maintaining a personal, prioritized queue of movies to watch.

Every feature should support one of these actions:

- Find a movie
- Add it to the queue
- Decide what to watch next
- Mark it watched
- Remember why it was added
