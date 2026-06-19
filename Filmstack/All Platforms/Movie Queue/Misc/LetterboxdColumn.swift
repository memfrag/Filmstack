//
//  Filmstack
//

import SwiftUI
import NukeUI

/// Shows films watched on Letterboxd (from the user's diary RSS feed) as a poster
/// grid. Tapping an entry with a TMDB id shows it in the detail pane.
struct LetterboxdColumn: View {

    @Binding var selection: BrowseSelection?

    @Environment(AppSettings.self) private var appSettings
    @Environment(\.openURL) private var openURL

    private let store = LetterboxdStore.shared
    @State private var usernameInput = ""

    private var username: String { appSettings.letterboxdUsername }

    var body: some View {
        VStack(spacing: 0) {
            header
            content
        }
        .filmWindowBackground()
        .navigationTitle("Letterboxd")
        .toolbar {
            if !username.isEmpty {
                ToolbarItem {
                    Menu {
                        Button("Refresh") { Task { await store.refresh(username: username) } }
                        Button("Change Username…") {
                            usernameInput = username
                            appSettings.letterboxdUsername = ""
                        }
                    } label: {
                        Label("Options", systemImage: "ellipsis.circle")
                    }
                }
            }
        }
        .task(id: username) {
            await store.ensureLoaded(username: username)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("Letterboxd")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Palette.textPrimary)
            if !username.isEmpty {
                Text("@\(username)")
                    .font(.title3)
                    .foregroundStyle(Palette.textSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, 22)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    @ViewBuilder private var content: some View {
        if username.isEmpty {
            usernamePrompt
        } else {
            switch store.phase {
            case .idle, .loading:
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            case .loaded(let entries) where entries.isEmpty:
                ContentUnavailableView("No Watched Films", systemImage: "film",
                                       description: Text("No diary entries found for @\(username)."))
            case .loaded(let entries):
                grid(entries)
            case .failed(let message):
                ContentUnavailableView {
                    Label("Couldn't Load", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(message)
                } actions: {
                    Button("Try Again") { Task { await store.refresh(username: username) } }
                    Button("Change Username") { appSettings.letterboxdUsername = "" }
                }
            }
        }
    }

    // MARK: - Username prompt

    private var usernamePrompt: some View {
        VStack(spacing: 14) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(Palette.accent.opacity(0.85))
            Text("Connect Letterboxd")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Palette.textPrimary)
            Text("Enter your Letterboxd username to show films from your public diary.")
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)

            HStack {
                TextField("username", text: $usernameInput)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .frame(maxWidth: 220)
                Button("Load") {
                    appSettings.letterboxdUsername = usernameInput
                }
                .buttonStyle(.filmAccent)
                .disabled(usernameInput.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Grid

    private func grid(_ entries: [LetterboxdEntry]) -> some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 116, maximum: 150), spacing: 16)],
                spacing: 18
            ) {
                ForEach(entries) { entry in
                    card(entry)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
    }

    private func card(_ entry: LetterboxdEntry) -> some View {
        let isSelected = entry.tmdbID != nil && selection?.id == entry.tmdbID
        return Button {
            if let result = entry.asSearchResult {
                selection = BrowseSelection(
                    result: result,
                    watchedDate: entry.watchedDate,
                    rating: entry.rating
                )
            } else if let link = entry.link {
                openURL(link)
            }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                poster(entry)
                    .aspectRatio(2.0 / 3.0, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(isSelected ? Palette.accent : Palette.hairline,
                                          lineWidth: isSelected ? 3 : 1)
                    }
                    .shadow(color: isSelected ? Palette.accent.opacity(0.4) : .black.opacity(0.4),
                            radius: isSelected ? 10 : 5, y: 3)

                Text(entry.title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1)

                if let watched = entry.watchedDateText {
                    HStack(spacing: 4) {
                        if let rating = entry.rating {
                            Text(String(format: "★ %.1f", rating))
                                .foregroundStyle(.yellow)
                        }
                        Text(watched)
                            .foregroundStyle(Palette.textSecondary)
                    }
                    .font(.caption2)
                    .lineLimit(1)
                }
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private func poster(_ entry: LetterboxdEntry) -> some View {
        if let url = entry.posterURL {
            LazyImage(url: url) { state in
                if let image = state.image { image.resizable().scaledToFill() } else { posterPlaceholder }
            }
        } else {
            posterPlaceholder
        }
    }

    private var posterPlaceholder: some View {
        Rectangle().fill(.fill.tertiary)
            .overlay { Image(systemName: "film").foregroundStyle(.secondary) }
    }
}
