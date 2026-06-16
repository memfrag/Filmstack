//
//  Filmstack
//

import SwiftUI
import SwiftData
import NukeUI

/// Confirmation step after picking a search result: fetches full details, lets the
/// user add optional notes/location/source, checks for duplicates, then adds the
/// movie to the library.
struct AddMovieConfirmation: View {

    let result: MovieSearchResult
    let defaultStatus: MovieStatus
    let model: MovieSearchModel
    let onAdded: () -> Void

    @Environment(\.modelContext) private var context

    enum Phase {
        case loading
        case loaded(MovieDetails)
        case failed(String)
    }

    @State private var phase: Phase = .loading
    @State private var notes = ""
    @State private var streamingLocation = ""
    @State private var source = ""
    @State private var alreadyInLibrary = false
    @State private var confirmWatchedAgain = false

    private var addButtonTitle: String {
        defaultStatus == .maybeLater ? "Add to Maybe Later" : "Add to Queue"
    }

    var body: some View {
        Form {
            switch phase {
            case .loading:
                Section {
                    HStack {
                        ProgressView()
                        Text("Loading details…").foregroundStyle(.secondary)
                    }
                }
            case .failed(let text):
                Section {
                    Label(text, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.secondary)
                    Button("Retry") { Task { await load() } }
                }
            case .loaded(let details):
                detailsHeader(details)
                optionalFields
            }
        }
        .formStyle(.grouped)
        .navigationTitle(result.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(addButtonTitle) { attemptAdd() }
                    .disabled(!isLoaded)
            }
        }
        .task { await load() }
        .alert("Already in your library", isPresented: $alreadyInLibrary) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This movie is already in your queue or maybe-later list.")
        }
        .confirmationDialog(
            "You already watched this movie. Add it again?",
            isPresented: $confirmWatchedAgain,
            titleVisibility: .visible
        ) {
            Button("Add Again") { commit() }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var isLoaded: Bool {
        if case .loaded = phase { return true }
        return false
    }

    // MARK: - Sections

    @ViewBuilder private func detailsHeader(_ details: MovieDetails) -> some View {
        Section {
            HStack(alignment: .top, spacing: 16) {
                poster
                    .frame(width: 100, height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(details.title)
                        .font(.title3.bold())
                    if let meta = metaLine(details) {
                        Text(meta).foregroundStyle(.secondary)
                    }
                    if !details.genres.isEmpty {
                        Text(details.genres.joined(separator: ", "))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
            if let overview = details.overview, !overview.isEmpty {
                Text(overview)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var optionalFields: some View {
        Section("Optional") {
            TextField("Notes", text: $notes, axis: .vertical)
                .lineLimit(2...4)
            TextField("Where can you watch it?", text: $streamingLocation)
            TextField("Where did you hear about it?", text: $source)
        }
    }

    @ViewBuilder private var poster: some View {
        let url = TMDBImage.posterURL(path: result.posterPath, size: .queue)
        if let url {
            LazyImage(url: url) { state in
                if let image = state.image {
                    image.resizable().scaledToFill()
                } else {
                    posterPlaceholder
                }
            }
        } else {
            posterPlaceholder
        }
    }

    private var posterPlaceholder: some View {
        Rectangle()
            .fill(.fill.tertiary)
            .overlay { Image(systemName: "film").foregroundStyle(.secondary) }
    }

    private func metaLine(_ details: MovieDetails) -> String? {
        var parts: [String] = []
        if let year = details.releaseYear { parts.append(String(year)) }
        if let runtime = details.runtimeMinutes, runtime > 0 {
            let hours = runtime / 60, mins = runtime % 60
            parts.append(hours > 0 ? "\(hours)h \(mins)m" : "\(mins)m")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    // MARK: - Actions

    private func load() async {
        phase = .loading
        do {
            let details = try await model.fetchDetails(for: result)
            phase = .loaded(details)
        } catch {
            phase = .failed((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }

    private func attemptAdd() {
        guard case .loaded = phase else { return }
        let existing = existingMovies()
        if existing.contains(where: { $0.status == .queued || $0.status == .maybeLater }) {
            alreadyInLibrary = true
        } else if existing.contains(where: { $0.status == .watched }) {
            confirmWatchedAgain = true
        } else {
            commit()
        }
    }

    private func commit() {
        guard case .loaded(let details) = phase else { return }
        let movie = Movie(
            details: details,
            userNotes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            source: source.nilIfBlank,
            streamingLocation: streamingLocation.nilIfBlank,
            status: defaultStatus
        )
        MovieActions.add(movie, in: context)
        onAdded()
    }

    private func existingMovies() -> [Movie] {
        let tmdbID = result.tmdbID
        let descriptor = FetchDescriptor<Movie>(
            predicate: #Predicate { $0.tmdbID == tmdbID }
        )
        return (try? context.fetch(descriptor)) ?? []
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
