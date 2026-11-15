//
//  Filmstack
//

import SwiftUI
import SwiftData
import NukeUI

/// A modal "help me pick" view: the queue as a 3D shelf of DVD cases.
///
/// The cases stream in on open and settle with the middle movie pulled out.
/// Tapping the front case flips it to its back cover; "Open Full Details"
/// dismisses and selects the movie in the queue.
struct MoviePickerView: View {

    let movies: [Movie]
    let title: String
    let position: (Movie) -> Int?
    let onOpenDetails: (Movie) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var appSettings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var scroll: ScrollPosition
    @State private var offset: CGFloat
    private let initialIndex: Int
    @State private var flippedID: PersistentIdentifier?
    @State private var intro: CGFloat = 0
    @State private var chromeVisible = false
    @State private var scrollPhase: ScrollPhase = .idle
    /// The shelf is coasting slowly within a hair of a case: as good as
    /// settled, a beat before the scroll view reports idle.
    @State private var isNearRest = false
    @State private var lastOffsetSample: (offset: CGFloat, time: Date)?
    /// The movie the blurred background shows. Held while the shelf moves and
    /// only updated once it comes to rest, so the backdrop doesn't flicker.
    @State private var backgroundMovieID: PersistentIdentifier?
    @FocusState private var keyboardFocused: Bool

    init(
        movies: [Movie],
        title: String,
        position: @escaping (Movie) -> Int?,
        onOpenDetails: @escaping (Movie) -> Void
    ) {
        self.movies = movies
        self.title = title
        self.position = position
        self.onOpenDetails = onOpenDetails
        let middle = movies.count / 2
        self.initialIndex = middle
        _offset = State(initialValue: CGFloat(middle))
        if movies.indices.contains(middle) {
            _scroll = State(initialValue: ScrollPosition(id: movies[middle].persistentModelID, anchor: .center))
        } else {
            _scroll = State(initialValue: ScrollPosition(idType: PersistentIdentifier.self))
        }
    }

    /// Where the shelf is drawn: pinned to the opening movie during the intro.
    private var displayOffset: CGFloat {
        isSettled ? offset : CGFloat(initialIndex)
    }

    private var focusedIndex: Int {
        min(max(Int(displayOffset.rounded()), 0), max(movies.count - 1, 0))
    }

    /// The shelf counts as moving until it is idle, or until it is coasting
    /// to a stop right on a case (never while a finger is on it).
    private var isMoving: Bool {
        switch scrollPhase {
        case .idle: false
        case .decelerating, .animating: !isNearRest
        default: true
        }
    }

    /// The case that is slid out of the crate: whichever is nearest the focus
    /// right now, even mid-scroll. Each case animates its own slide, so one
    /// that loses the focus glides back in from wherever it got to.
    private var pullIndex: Int? { focusedIndex }

    private var backgroundMovie: Movie? {
        guard let backgroundMovieID else { return focusedMovie }
        return movies.first { $0.persistentModelID == backgroundMovieID } ?? focusedMovie
    }

    /// +1 when the shelf moved forward from the settled movie, -1 when back.
    /// Updated while scrolling, so it is in place before the title swaps.
    @State private var titleDirection: CGFloat = 1

    private func settleBackground() {
        guard !isMoving, abs(offset - offset.rounded()) < 0.15,
              backgroundMovieID != focusedMovie?.persistentModelID else { return }
        withAnimation(.easeInOut(duration: 0.5)) {
            backgroundMovieID = focusedMovie?.persistentModelID
        }
    }

    private var focusedMovie: Movie? {
        movies.indices.contains(focusedIndex) ? movies[focusedIndex] : nil
    }

    /// True once the intro animation has finished. `intro` itself jumps to 1
    /// as soon as the animation starts, so it can't gate the pinned offset.
    @State private var introDone = false

    private var isSettled: Bool { introDone }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            titleBlock
                .opacity(chromeVisible ? 1 : 0)
            DVDShelf(
                movies: movies,
                position: position,
                scroll: $scroll,
                scrollOffset: $offset,
                offset: displayOffset,
                flippedID: flippedID,
                intro: intro,
                pullIndex: pullIndex,
                isInteractive: isSettled,
                onPhaseChange: { scrollPhase = $0 },
                onTapCase: tapCase,
                onTapFlipped: { setFlipped(nil) },
                onOpenDetails: openDetails
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            bottomBar
                .opacity(chromeVisible ? 1 : 0)
                .offset(y: chromeVisible ? 0 : 20)
        }
        .background { background }
        .preferredColorScheme(.dark)
        .focusable()
        .focusEffectDisabled()
        .focused($keyboardFocused)
        .onKeyPress(.leftArrow) { step(-1) }
        .onKeyPress(.rightArrow) { step(1) }
        .onKeyPress(.return) { toggleFlip() }
        .onKeyPress(.space) { toggleFlip() }
        .onKeyPress(.escape) {
            dismiss()
            return .handled
        }
        .onChange(of: isMoving) { settleBackground() }
        .task(id: backgroundMovie?.persistentModelID) {
            if let movie = backgroundMovie { await refreshProvidersIfStale(movie) }
        }
        .onChange(of: offset) { _, newOffset in
            let now = Date()
            if let last = lastOffsetSample {
                let elapsed = max(now.timeIntervalSince(last.time), 1.0 / 240)
                let velocity = (newOffset - last.offset) / CGFloat(elapsed)
                // Where the coast would end at this velocity (scroll views
                // decelerate roughly exponentially, ~0.35 s time constant).
                // Settled only once that is the case the shelf is already on,
                // so slowly passing a case never counts.
                let projected = newOffset + velocity * 0.35
                let nearRest = abs(newOffset - newOffset.rounded()) < 0.15
                    && projected.rounded() == newOffset.rounded()
                    && abs(projected - newOffset.rounded()) < 0.2
                if nearRest != isNearRest { isNearRest = nearRest }
            }
            lastOffsetSample = (newOffset, now)
            if !isMoving { settleBackground() }
        }
        .onChange(of: focusedIndex) { _, newIndex in
            if let settled = movies.firstIndex(where: { $0.persistentModelID == backgroundMovie?.persistentModelID }),
               newIndex != settled {
                titleDirection = newIndex > settled ? 1 : -1
            }
            settleBackground()
            if flippedID != nil, flippedID != focusedMovie?.persistentModelID {
                setFlipped(nil)
            }
        }
        .onChange(of: movies.count) { _, count in
            if count == 0 { dismiss() }
        }
        #if os(iOS)
        .sensoryFeedback(.selection, trigger: focusedIndex)
        #endif
        .task { await playIntro() }
    }

    // MARK: - Chrome

    private var topBar: some View {
        ZStack {
            Text("\(title.uppercased()) · \(movies.count == 1 ? "1 MOVIE" : "\(movies.count) MOVIES")")
                .font(.caption.weight(.semibold))
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.6))
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .glassEffect(.regular.interactive(), in: Circle())
                .accessibilityLabel("Close")
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    /// The shelf is moving after the intro (scroll, arrow keys or
    /// Random Pick).
    private var headerInMotion: Bool { isSettled && isMoving }

    @ViewBuilder private var titleBlock: some View {
        VStack(spacing: 6) {
            if let movie = backgroundMovie {
                Group {
                    // One line: shrink to fit first, then truncate.
                    Text(movie.title)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .truncationMode(.tail)
                    Text(subtitle(for: movie))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.75))
                    ProviderIconRow(providers: movie.watchProviders)
                        .padding(.top, 4)
                }
                .id(movie.persistentModelID)
                .transition(MotionBlurTransition(direction: titleDirection))
            }
        }
        // Fixed height (title, subtitle and icon row), so the header never
        // moves the crate below it, whatever it contains.
        .frame(maxWidth: .infinity)
        .frame(height: 92, alignment: .top)
        .padding(.horizontal, 24)
        .padding(.top, 14)
        .animation(.smooth(duration: 0.45), value: backgroundMovie?.persistentModelID)
        // Smear the title as soon as the shelf starts moving; it sharpens again
        // when the shelf settles (swapping to the new movie if focus changed).
        .scaleEffect(x: headerInMotion ? 1.12 : 1, y: 1)
        .blur(radius: headerInMotion ? 7 : 0)
        .opacity(headerInMotion ? 0.55 : 1)
        .animation(.smooth(duration: headerInMotion ? 0.18 : 0.35), value: headerInMotion)
    }

    private func subtitle(for movie: Movie) -> String {
        [movie.yearText, movie.genres.first, movie.runtimeText]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    private var bottomBar: some View {
        VStack(spacing: 14) {
            if movies.count > 1 {
                Button(action: pickForMe) {
                    Label("Random Pick", systemImage: "shuffle")
                        .padding(.horizontal, 10)
                }
                .buttonStyle(.filmGlass)
                .disabled(!isSettled)
            }
        }
        .padding(.bottom, 20)
        .frame(minHeight: 60)
    }

    @ViewBuilder private var background: some View {
        ZStack {
            // The generic backdrop, seen while the shelf moves (and for movies
            // without a poster): the app's wash with a bright violet glow in the
            // middle, so the dark cases keep their contrast.
            Gradients.window
            RadialGradient(
                colors: [
                    Palette.accentBright.opacity(0.75),
                    Palette.accent.opacity(0.45),
                    Palette.accent.opacity(0)
                ],
                center: UnitPoint(x: 0.5, y: 0.52),
                startRadius: 0,
                endRadius: 520
            )
            if let movie = backgroundMovie,
               let url = TMDBImage.posterURL(path: movie.posterPath, size: .thumbnail) {
                LazyImage(url: url) { state in
                    if let image = state.image {
                        image.resizable().scaledToFill()
                    }
                }
                .id(movie.persistentModelID)
                .transition(MotionBlurTransition(direction: titleDirection))
                .blur(radius: 60)
                .scaleEffect(1.3)
                // Kept bright, so the dark cases stand out against it.
                .saturation(1.15)
                .brightness(0.06)
                // While the shelf moves, fall back to the generic wash; the
                // settled movie's backdrop fades in once it comes to rest.
                .opacity(headerInMotion ? 0 : 1)
                .animation(.easeInOut(duration: 0.4), value: headerInMotion)
            }
            Color.black.opacity(0.12)
            // A soft scrim behind the header keeps the white title readable
            // over bright backdrops.
            LinearGradient(
                colors: [.black.opacity(0.45), .black.opacity(0)],
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.35)
            )
        }
        .animation(.easeInOut(duration: 0.5), value: backgroundMovie?.persistentModelID)
        .clipped()
        .ignoresSafeArea()
    }

    // MARK: - Actions

    private func playIntro() async {
        keyboardFocused = true
        // Make sure the input scroll view really sits on the opening movie,
        // so nothing jumps when the intro hands over to it.
        if movies.indices.contains(initialIndex) {
            scroll.scrollTo(id: movies[initialIndex].persistentModelID, anchor: .center)
        }
        if reduceMotion {
            withAnimation(.easeInOut(duration: 0.35)) {
                intro = 1
                chromeVisible = true
            } completion: {
                introDone = true
            }
            return
        }
        withAnimation(.timingCurve(0.25, 0.6, 0.3, 1, duration: 1.9)) {
            intro = 1
        } completion: {
            introDone = true
        }
        try? await Task.sleep(for: .seconds(1.4))
        withAnimation(.smooth(duration: 0.4)) {
            chromeVisible = true
        }
    }

    private func tapCase(_ index: Int) {
        guard movies.indices.contains(index) else { return }
        if index == focusedIndex {
            setFlipped(movies[index].persistentModelID)
        } else {
            scrollTo(index, animated: true)
        }
    }

    private func toggleFlip() -> KeyPress.Result {
        guard isSettled, let movie = focusedMovie else { return .ignored }
        setFlipped(flippedID == nil ? movie.persistentModelID : nil)
        return .handled
    }

    /// Fetches where the settled movie can be watched when that has never been
    /// fetched or is over a week old (as the detail view does). Best-effort.
    private func refreshProvidersIfStale(_ movie: Movie) async {
        guard let tmdbID = movie.tmdbID else { return }
        let weekAgo = Date(timeIntervalSinceNow: -7 * 24 * 60 * 60)
        if let updated = movie.watchProvidersUpdatedAt, updated > weekAgo { return }
        guard let availability = try? await AppEnvironment.default.movieAPIClient
            .fetchWatchProviders(tmdbID: tmdbID, region: appSettings.releaseRegion),
              movie.modelContext != nil else { return }
        withAnimation(.smooth(duration: 0.3)) {
            movie.watchProviders = availability.providers
        }
        movie.justWatchURL = availability.link
        movie.watchProvidersUpdatedAt = Date()
        movie.updatedAt = Date()
        try? context.save()
    }

    private func setFlipped(_ id: PersistentIdentifier?) {
        withAnimation(.spring(duration: 0.85, bounce: 0.1)) {
            flippedID = id
        }
    }

    private func step(_ delta: Int) -> KeyPress.Result {
        guard isSettled, !movies.isEmpty else { return .ignored }
        scrollTo(min(max(focusedIndex + delta, 0), movies.count - 1), animated: true)
        return .handled
    }

    private func scrollTo(_ index: Int, animated: Bool) {
        guard movies.indices.contains(index) else { return }
        let id = movies[index].persistentModelID
        if animated {
            withAnimation(.smooth(duration: 0.45)) {
                scroll.scrollTo(id: id, anchor: .center)
            }
        } else {
            scroll.scrollTo(id: id, anchor: .center)
        }
    }

    private func pickForMe() {
        let candidates = movies.indices.filter { $0 != focusedIndex }
        guard let pick = candidates.randomElement() else { return }
        setFlipped(nil)
        let id = movies[pick].persistentModelID
        withAnimation(.smooth(duration: 0.9)) {
            scroll.scrollTo(id: id, anchor: .center)
        }
    }

    private func openDetails(_ movie: Movie) {
        onOpenDetails(movie)
        dismiss()
    }
}

#if DEBUG
#Preview {
    let container = MovieStore.previewContainer
    let movies = SampleMovies.makeMovies()
    MoviePickerView(
        movies: movies,
        title: "Queue",
        position: { movie in movies.firstIndex { $0 === movie }.map { $0 + 1 } },
        onOpenDetails: { _ in }
    )
    .modelContainer(container)
    .environment(AppSettings.mock())
}
#endif

/// Swaps the title like it is whipping past: the old one smears off in the
/// direction of travel and the new one smears in from the other side.
private struct MotionBlurTransition: Transition {

    /// +1 moving forward (content travels left), -1 moving back.
    let direction: CGFloat

    func body(content: Content, phase: TransitionPhase) -> some View {
        let t = abs(phase.value)
        content
            .scaleEffect(x: 1 + 0.35 * t, y: 1 - 0.04 * t)
            .blur(radius: 9 * t)
            .offset(x: -phase.value * direction * 70)
            .opacity(1 - t)
    }
}
