//
//  Filmstack
//

import SwiftUI
import SwiftData

/// Sidebar list backing `SplitRoot`'s NavigationSplitView leading column.
///
/// Selection drives the movie list column via the shared
/// `Router<MainRouting>.activeSelectable` binding.
struct Sidebar: View {

    @Binding var selection: MainRouting.Selectable
    @Binding var filter: LibraryFilter

    @Query private var movies: [Movie]

    private let sections: [MainRouting.Selectable] = [.queue, .watched, .maybeLater]

    /// Genres present anywhere in the library, sorted.
    private var genres: [String] {
        Set(movies.flatMap(\.genres)).sorted()
    }

    /// Sources present anywhere in the library, sorted.
    private var sources: [String] {
        Set(movies.compactMap { $0.source?.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }).sorted()
    }

    var body: some View {
        List(selection: Binding(
            get: { Optional(selection) },
            set: { if let new = $0 { selection = new } }
        )) {
            Section {
                ForEach(sections, id: \.self) { section in
                    NavigationLink(value: section) {
                        Label(section.movieStatus.title, systemImage: section.movieStatus.systemImage)
                            .badge(count(for: section.movieStatus))
                    }
                }
            } header: {
                Text("Library")
                    .foregroundStyle(Palette.textSecondary)
            }

            filtersSection
        }
        .scrollContentBackground(.hidden)
        .background(Palette.sidebar)
        .tint(Palette.accent)
        .navigationTitle(Bundle.main.appName)
        #if os(macOS)
        .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
        .safeAreaInset(edge: .bottom) {
            settingsButton
        }
        #endif
    }

    // MARK: - Filters

    @ViewBuilder private var filtersSection: some View {
        Section {
            filterRow(.all, label: "All", systemImage: "square.stack.3d.up")

            if !genres.isEmpty {
                DisclosureGroup {
                    ForEach(genres, id: \.self) { genre in
                        filterRow(.genre(genre), label: genre)
                    }
                } label: {
                    Label("By Genre", systemImage: "theatermasks")
                }
            }

            if !sources.isEmpty {
                DisclosureGroup {
                    ForEach(sources, id: \.self) { source in
                        filterRow(.source(source), label: source)
                    }
                } label: {
                    Label("By Source", systemImage: "sparkles")
                }
            }
        } header: {
            Text("Filters")
                .foregroundStyle(Palette.textSecondary)
        }
    }

    private func filterRow(_ value: LibraryFilter, label: String, systemImage: String? = nil) -> some View {
        Button {
            filter = value
        } label: {
            HStack {
                if let systemImage {
                    Label(label, systemImage: systemImage)
                } else {
                    Text(label)
                }
                Spacer()
                if filter == value {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Palette.accent)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(filter == value ? Palette.textPrimary : Palette.textSecondary)
    }

    private func count(for status: MovieStatus) -> Int {
        movies.lazy.filter { $0.statusRawValue == status.rawValue }.count
    }

    #if os(macOS)
    @ViewBuilder private var settingsButton: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Palette.separator).frame(height: 1)
            SettingsLink {
                Label("Settings", systemImage: "gearshape")
                    .foregroundStyle(Palette.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .background(Palette.sidebar)
    }
    #endif
}

private extension Bundle {
    var appName: String {
        (object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? "Filmstack"
    }
}

#Preview {
    NavigationSplitView {
        Sidebar(selection: .constant(.queue), filter: .constant(.all))
    } detail: {
        Text("Detail")
    }
    .modelContainer(MovieStore.previewContainer)
}
