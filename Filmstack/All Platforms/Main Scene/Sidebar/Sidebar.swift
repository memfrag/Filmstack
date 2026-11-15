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

    @Environment(AppSettings.self) private var appSettings

    @Query private var movies: [Movie]

    var body: some View {
        List(selection: Binding(
            get: { Optional(selection) },
            set: { if let new = $0 { selection = new } }
        )) {
            Section {
                ForEach(MainRouting.Selectable.visibleLibraryCases(showingMaybeLater: appSettings.showsMaybeLater), id: \.self) { section in
                    NavigationLink(value: section) {
                        Label(section.title, systemImage: section.systemImage)
                            .badge(count(for: section))
                    }
                }
            } header: {
                Text("Library")
                    .foregroundStyle(Palette.textSecondary)
            }

            Section {
                ForEach(MainRouting.Selectable.discoverCases, id: \.self) { section in
                    NavigationLink(value: section) {
                        Label(section.title, systemImage: section.systemImage)
                    }
                }
            } header: {
                Text("Discover")
                    .foregroundStyle(Palette.textSecondary)
            }

            Section {
                ForEach(MainRouting.Selectable.miscCases, id: \.self) { section in
                    NavigationLink(value: section) {
                        Label(section.title, systemImage: section.systemImage)
                    }
                }
            } header: {
                Text("Miscellaneous")
                    .foregroundStyle(Palette.textSecondary)
            }

            #if os(iOS)
            Section {
                NavigationLink(value: MainRouting.Selectable.profile) {
                    Label("Profile", systemImage: "person.fill")
                }
            }
            #endif
        }
        .scrollContentBackground(.hidden)
        .background(Palette.sidebar)
        .tint(Palette.accent)
        .navigationTitle(Bundle.main.appName)
        .onChange(of: appSettings.showsMaybeLater) { _, shows in
            if !shows && selection == .maybeLater { selection = .queue }
        }
        #if os(macOS)
        .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
        .safeAreaInset(edge: .bottom) {
            settingsButton
        }
        #endif
    }

    private func count(for section: MainRouting.Selectable) -> Int {
        if let status = section.status {
            return movies.lazy.filter { $0.statusRawValue == status.rawValue }.count
        }
        // Upcoming: non-watched movies with a future release date.
        let watchedRaw = MovieStatus.watched.rawValue
        let now = Date()
        return movies.lazy.filter {
            $0.statusRawValue != watchedRaw && ($0.releaseDate ?? .distantPast) > now
        }.count
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

#if DEBUG
#Preview {
    NavigationSplitView {
        Sidebar(selection: .constant(.queue))
    } detail: {
        Text("Detail")
    }
    .environment(AppSettings.mock())
    .modelContainer(MovieStore.previewContainer)
}
#endif
