//
//  Filmstack
//

import SwiftUI

/// Popover for enabling one or more genre/source filters on the current list.
struct FilterPopover: View {

    @Binding var filter: LibraryFilter
    let genres: [String]
    let sources: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !genres.isEmpty {
                        group(
                            "Genre",
                            items: genres,
                            isOn: { filter.genres.contains($0) },
                            toggle: { filter.toggleGenre($0) }
                        )
                    }
                    if !sources.isEmpty {
                        group(
                            "Source",
                            items: sources,
                            isOn: { filter.sources.contains($0) },
                            toggle: { filter.toggleSource($0) }
                        )
                    }
                }
                .padding(16)
            }
        }
        .frame(width: 250, height: 340)
    }

    private var header: some View {
        HStack {
            Text("Filters")
                .font(.headline)
            Spacer()
            if filter.isActive {
                Button("Clear") { filter.clear() }
                    .buttonStyle(.plain)
                    .font(.callout)
                    .foregroundStyle(Palette.accent)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Palette.separator).frame(height: 1)
        }
    }

    private func group(
        _ title: String,
        items: [String],
        isOn: @escaping (String) -> Bool,
        toggle: @escaping (String) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption.bold())
                .foregroundStyle(Palette.textSecondary)
                .padding(.bottom, 2)

            ForEach(items, id: \.self) { item in
                Button {
                    toggle(item)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: isOn(item) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(isOn(item) ? Palette.accent : Palette.textSecondary)
                        Text(item)
                            .foregroundStyle(Palette.textPrimary)
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview {
    FilterPopover(
        filter: .constant(LibraryFilter(genres: ["Drama"])),
        genres: ["Action", "Adventure", "Drama", "Sci-Fi"],
        sources: ["Friend", "Podcast"]
    )
}
