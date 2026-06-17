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

    @Query private var movies: [Movie]

    private let sections: [MainRouting.Selectable] = [.queue, .watched, .maybeLater]

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
        Sidebar(selection: .constant(.queue))
    } detail: {
        Text("Detail")
    }
    .modelContainer(MovieStore.previewContainer)
}
