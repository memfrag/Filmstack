//
//  Filmstack
//

import SwiftUI
import SwiftData

/// Sheet for manually adding a movie, or editing an existing one.
///
/// TMDB search-based adding is layered on later; this manual form is always
/// available, including when no TMDB token is configured.
struct MovieFormSheet: View {

    enum Mode {
        case add(defaultStatus: MovieStatus)
        case edit(Movie)
    }

    let mode: Mode

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var year = ""
    @State private var notes = ""
    @State private var source = ""
    @State private var status: MovieStatus = .queued

    @State private var showingDuplicateConfirmation = false

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $title)
                    TextField("Year", text: $year)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                }

                Section("Optional") {
                    Picker("Status", selection: $status) {
                        ForEach(MovieStatus.allCases, id: \.self) { status in
                            Text(status.title).tag(status)
                        }
                    }
                    TextField("Where did you hear about it?", text: $source)
                }

                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(isEditing ? "Edit Movie" : "Add Movie")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add") { attemptSave() }
                        .disabled(trimmedTitle.isEmpty)
                }
            }
            .confirmationDialog(
                "A similar movie already exists.",
                isPresented: $showingDuplicateConfirmation,
                titleVisibility: .visible
            ) {
                Button("Add Anyway") { commitAdd() }
                Button("Cancel", role: .cancel) {}
            }
        }
        .frame(minWidth: 420, minHeight: 440)
        .onAppear(perform: loadInitialValues)
    }

    // MARK: - Loading

    private func loadInitialValues() {
        switch mode {
        case .add(let defaultStatus):
            status = defaultStatus
        case .edit(let movie):
            title = movie.title
            year = movie.releaseYear.map(String.init) ?? ""
            notes = movie.userNotes
            source = movie.source ?? ""
            status = movie.status
        }
    }

    // MARK: - Saving

    private var parsedYear: Int? {
        Int(year.trimmingCharacters(in: .whitespaces))
    }

    private func attemptSave() {
        switch mode {
        case .add:
            if hasPossibleDuplicate() {
                showingDuplicateConfirmation = true
            } else {
                commitAdd()
            }
        case .edit(let movie):
            apply(to: movie)
            MovieActions.save(edited: movie, in: context)
            dismiss()
        }
    }

    private func commitAdd() {
        let movie = Movie(
            title: trimmedTitle,
            releaseYear: parsedYear,
            userNotes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            source: source.nilIfBlank,
            status: status
        )
        MovieActions.add(movie, in: context)
        dismiss()
    }

    private func apply(to movie: Movie) {
        movie.title = trimmedTitle
        movie.releaseYear = parsedYear
        movie.userNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        movie.source = source.nilIfBlank
        movie.status = status
    }

    /// Soft duplicate check by title and year.
    private func hasPossibleDuplicate() -> Bool {
        let needle = trimmedTitle.localizedLowercase
        let year = parsedYear
        let descriptor = FetchDescriptor<Movie>()
        let existing = (try? context.fetch(descriptor)) ?? []
        return existing.contains { movie in
            movie.title.localizedLowercase == needle && movie.releaseYear == year
        }
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

#Preview("Add") {
    MovieFormSheet(mode: .add(defaultStatus: .queued))
        .modelContainer(MovieStore.previewContainer)
}
