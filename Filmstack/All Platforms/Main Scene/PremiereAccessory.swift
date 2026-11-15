//
//  Filmstack
//

#if os(iOS)

import SwiftUI

/// The tab bar accessory shown when a movie in the library premieres today.
/// Tapping it opens the movie (the first one, if several premiere).
struct PremiereAccessory: View {

    /// Today's premieres; never empty while the accessory is shown.
    let movies: [Movie]
    let onOpen: (Movie) -> Void

    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    var body: some View {
        if let first = movies.first {
            Button {
                onOpen(first)
            } label: {
                HStack(spacing: 10) {
                    if placement != .inline {
                        PosterView(movie: first, size: .thumbnail, cornerRadius: 4)
                            .frame(height: 34)
                    } else {
                        Image(systemName: "sparkles")
                            .foregroundStyle(Palette.accentBright)
                    }
                    VStack(alignment: .leading, spacing: 0) {
                        if placement != .inline {
                            Text("Premieres Today")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Palette.accentBright)
                        }
                        Text(title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Palette.textPrimary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Palette.textSecondary)
                }
                .padding(.horizontal, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Premieres today: \(movies.map(\.title).joined(separator: ", "))")
        }
    }

    /// "Dune" or "Dune + 2 more".
    private var title: String {
        guard let first = movies.first else { return "" }
        let others = movies.count - 1
        return others > 0 ? String(localized: "\(first.title) + \(others) more") : first.title
    }

    // MARK: - Today

    /// Whether a TMDB release date (midnight UTC on the release day) falls on
    /// the user's current calendar day.
    static func premieresToday(_ releaseDate: Date?, now: Date = Date()) -> Bool {
        guard let releaseDate else { return false }
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC") ?? utc.timeZone
        let release = utc.dateComponents([.year, .month, .day], from: releaseDate)
        let today = Calendar.current.dateComponents([.year, .month, .day], from: now)
        return release.year == today.year && release.month == today.month && release.day == today.day
    }
}

#endif
