# Filmstack

A native multiplatform (macOS / iOS / iPadOS) SwiftUI app for tracking a personal
movie queue — what to watch, what's upcoming, what you've seen. Built on an
Apparata AB boilerplate. The core feature spec lives in
`docs/movie_queue_macos_app_spec.md`.

## Platform & toolchain

- **Swift 6.2**, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` (everything is
  `@MainActor` by default). Plain data/helper types that must run off the main
  actor (RSS parsers, enums used from background tasks) need explicit
  `nonisolated`.
- Deployment targets: **macOS 26.3**, **iOS 26.4**.
- Bundle id `io.apparata.Filmstack`, team `DR5YAK7GKS` (Apparata AB). The repo
  owner is the boilerplate author.

## Project layout

Single app target **Filmstack** using **synchronized folder groups**
(`PBXFileSystemSynchronizedRootGroup`). New files under `Filmstack/` are picked
up automatically — **do not hand-edit `project.pbxproj` to add files.**

- `Filmstack/All Platforms/` — shared code (the bulk of the app)
  - `Movie Queue/` — the core feature
    - `Model/` — SwiftData `@Model Movie`, `MovieStore`, display helpers, `SampleMovies` (DEBUG)
    - `TMDB/` — TMDB search/details/discover client (Bearer token auth)
    - `Discover/` — Now Playing / Popular / Top Rated / Upcoming, with per-day disk cache
    - `Misc/` — Letterboxd diary RSS integration
    - `Views/` — list/grid/detail columns, rows, rating control
    - `Design/` — `FilmstackTheme` (Palette, Gradients) + `FilmstackStyle` (button styles, badges, backgrounds)
    - `Add Movie/`, `Settings/`
  - `App Environment/` — `AppEnvironment` dependency container (live + mock)
  - `Routing/` — `MainRouting` / `Selectable` (AppRouting package)
  - `Main Scene/` — `SplitRoot` (macOS/iPad 3-column), `PhoneTabRoot` (iPhone tabs)
- `Filmstack/iOS/`, `Filmstack/macOS/` — platform-specific scenes, menus, splash, etc.
- `Packages/AppDesign/` — local design package.
- `Scripts/` — release/build scripts. `docs/` — spec.

## Architecture notes

- **Dependency injection**: `AppEnvironment` (holds `MovieAPIClient`, `APIKeyStore`,
  etc.), injected with `.appEnvironment(_:)`. Live vs mock variants.
- **Routing**: Apparata `AppRouting` — `MainRouting: Routing`,
  `Selectable: SelectableDestination` (requires `CaseIterable`; the enum has an
  associated-value case `discover(DiscoverList)`, so `allCases` is written
  manually). Sections: `queue`, `upcoming`, `watched`, `maybeLater`,
  `discover(...)`, `letterboxd`.
- **Persistence**: SwiftData. `Movie` stores status as `statusRawValue: String`.
  `@Query` with `#Predicate`; identify by `\.persistentModelID`.
- **iCloud**: SwiftData + CloudKit auto-sync via entitlements
  (`Filmstack/Filmstack.entitlements`); `remote-notification` background mode in
  both Info.plists.
- **Images**: NukeUI `LazyImage` for poster loading/caching (`PosterView`).
- **External data**: TMDB (Bearer token in Keychain via `KeychainAPIKeyStore`);
  Letterboxd public RSS (`letterboxd.com/<user>/rss/`, needs a browser
  `User-Agent`, parsed `nonisolated` on a detached task). Watch providers via
  TMDB `watch/providers` (JustWatch attribution required).

## Conventions

- **File header**: start each Swift file with:
  ```swift
  //
  //  Filmstack
  //
  ```
- **Platform gating**: wrap platform-specific UI in `#if os(iOS)` / `#if os(macOS)`.
- **Previews & mocks**: all mock/sample infrastructure is `#if DEBUG`
  (`AppEnvironment.mock()`, `MovieStore.previewContainer`, `SampleMovies`,
  `InMemoryAPIKeyStore`, `MockMovieAPIClient`, `AppSettings.mock()`).
  **Any `#Preview` that references them MUST be wrapped in `#if DEBUG` / `#endif`**
  — `#Preview` macros still expand in Release archives, so an unguarded preview
  breaks the release build.
- **Design system**: use `Palette`/`Gradients`, the `.filmAccent`/`.filmGlass`
  button styles, `.filmWindowBackground()`, `.filmCard`, `RatingBadge`. Stretchy
  headers come from SwiftUIToolbox's `stretchyHeader()` (don't redefine it).
- **Lint**: SwiftLint via mint (`Mintfile` → `realm/SwiftLint`), allowlist config
  in `.swiftlint.yml`.

## Building & verifying

Schemes are **`Filmstack (Debug)`** and **`Filmstack (Release)`** — there is no
plain `Filmstack` scheme.

```bash
# macOS
xcodebuild build -project Filmstack.xcodeproj -scheme 'Filmstack (Debug)' \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath /tmp/filmstack-dd CODE_SIGNING_ALLOWED=NO

# iOS
xcodebuild build -project Filmstack.xcodeproj -scheme 'Filmstack (Debug)' \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/filmstack-dd-ios CODE_SIGNING_ALLOWED=NO
```

- **SourceKit diagnostics in this environment are unreliable** — false
  "No such module 'NukeUI'" and "Cannot find type" errors are common. Trust
  `xcodebuild`, not the inline diagnostics.
- Run the app from **Xcode** (a standalone `open` of the debug `.app` fails to
  find `Sparkle.framework` due to Xcode's debug-dylib rpath — not a code bug).

### Release (Developer ID + notarization)

`./Scripts/build-and-notarize.sh` — archives (pinned to
`-destination 'generic/platform=macOS'`), exports with `developer-id`, notarizes,
builds a DMG, signs for Sparkle, cuts a GitHub release, and updates
`appcast.xml`. It is **interactive** and needs a Developer ID identity, a
`notary` keychain profile, Sparkle keys, and `gh auth`. Version is driven by
`MARKETING_VERSION`/`CURRENT_PROJECT_VERSION` in the pbxproj
(`GENERATE_INFOPLIST_FILE = YES`).

## Git workflow

- Commit and push directly on **`main`** — **no branches**.
- **Do not credit Claude / add co-author trailers** in commit messages.
