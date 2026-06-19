//
//  Filmstack
//

import SwiftUI
import NukeUI

/// Shows streaming availability as pills grouped by access type (Stream / Rent /
/// Buy), with a JustWatch attribution. Each pill opens the region JustWatch page.
struct WatchProvidersView: View {

    let providers: [WatchProvider]
    let justWatchURL: URL?

    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(WatchProvider.Access.allCases, id: \.self) { access in
                group(access)
            }
            attribution
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private func group(_ access: WatchProvider.Access) -> some View {
        let items = providers.filter { $0.access == access }
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text(access.title.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Palette.textSecondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(items, id: \.self) { provider in
                            chip(provider)
                        }
                    }
                }
            }
        }
    }

    private func chip(_ provider: WatchProvider) -> some View {
        Button {
            if let justWatchURL { openURL(justWatchURL) }
        } label: {
            HStack(spacing: 7) {
                if let url = TMDBImage.logoURL(path: provider.logoPath) {
                    LazyImage(url: url) { state in
                        if let image = state.image {
                            image.resizable().scaledToFit()
                        } else {
                            Color.clear
                        }
                    }
                    .frame(width: 22, height: 22)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                }
                Text(provider.name)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1)
                    .fixedSize()
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 11)
            .background(Palette.card, in: Capsule())
            .overlay { Capsule().strokeBorder(Palette.hairline) }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .fixedSize()
        .disabled(justWatchURL == nil)
        .help(justWatchURL == nil ? "" : "Open on JustWatch")
    }

    @ViewBuilder private var attribution: some View {
        if let justWatchURL {
            Link("Powered by JustWatch", destination: justWatchURL)
                .font(.caption2)
                .foregroundStyle(Palette.textSecondary)
        } else {
            Text("Powered by JustWatch")
                .font(.caption2)
                .foregroundStyle(Palette.textSecondary)
        }
    }
}
