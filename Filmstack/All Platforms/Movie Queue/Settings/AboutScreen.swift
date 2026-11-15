//
//  Filmstack
//

import SwiftUI

/// About / Credits screen. Carries the required TMDB attribution, a short privacy
/// note, and links to TMDB and the open-source licenses.
struct AboutScreen: View {

    @Environment(\.openURL) private var openURL
    @State private var showingLicenses = false

    private let tmdbURL = URL(string: "https://www.themoviedb.org")!

    /// Required, verbatim, by TMDB's terms.
    private let tmdbAttribution =
        "This product uses the TMDB API but is not endorsed or certified by TMDB."

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                appHeader
                tmdbCredit
                links
                privacyNote
            }
            .padding(24)
            .frame(maxWidth: 460)
            .frame(maxWidth: .infinity)
        }
        .background(Palette.base)
        #if os(macOS)
        .navigationTitle("About")
        #else
        // The icon and app name head the page, so no title above them.
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(isPresented: $showingLicenses) {
            licensesSheet
        }
    }

    // MARK: - Sections

    private var appHeader: some View {
        VStack(spacing: 12) {
            AppIconView(size: 88)
                .shadow(color: Palette.accent.opacity(0.5), radius: 16, y: 8)

            Text("Filmstack")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Palette.textPrimary)

            Text("What should I watch next?")
                .foregroundStyle(Palette.textSecondary)

            if let version = AppVersion.appVersionString {
                Text("Version \(version) (\(AppVersion.buildVersionString ?? "—"))")
                    .font(.footnote)
                    .foregroundStyle(Palette.textSecondary.opacity(0.8))
            }
        }
    }

    private var tmdbCredit: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MOVIE DATA")
                .font(.caption.bold())
                .foregroundStyle(Palette.accentBright)

            tmdbLogo
                .frame(height: 26)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(tmdbAttribution)
                .font(.footnote)
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .filmCard()
    }

    /// The official TMDB logo if bundled, otherwise a styled text fallback.
    @ViewBuilder private var tmdbLogo: some View {
        if let image = bundledTMDBLogo {
            image
                .resizable()
                .scaledToFit()
                .accessibilityLabel("The Movie Database")
        } else {
            HStack(spacing: 12) {
                Text("TMDB")
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.vertical, 7)
                    .padding(.horizontal, 13)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.0, green: 0.71, blue: 0.84),
                                     Color(red: 0.13, green: 0.85, blue: 0.71)],
                            startPoint: .leading, endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )
                Text("The Movie Database")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(Palette.textPrimary)
            }
        }
    }

    private var bundledTMDBLogo: Image? {
        #if os(macOS)
        return NSImage(named: "TMDBLogo").map { Image(nsImage: $0) }
        #else
        return UIImage(named: "TMDBLogo").map { Image(uiImage: $0) }
        #endif
    }

    private var privacyNote: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PRIVACY")
                .font(.caption.bold())
                .foregroundStyle(Palette.accentBright)
            Text("""
            Filmstack is for personal, non-commercial use. There's no account, \
            backend, or analytics. Your movie library is stored on your devices \
            and, if iCloud is on, synced between them through your own iCloud \
            account. Your TMDB token stays in this device's Keychain and isn't synced.

            The Apple Intelligence features (moods, smart search, Smart Pick, \
            photo lookup, recommendations and your year recap) run on your \
            device. Some larger requests may use Apple's Private Cloud Compute, \
            which processes them without storing your data or making it \
            available to Apple. Nothing is sent to the developer.
            """)
            .font(.footnote)
            .foregroundStyle(Palette.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .filmCard()
    }

    private var links: some View {
        VStack(spacing: 10) {
            Button {
                openURL(tmdbURL)
            } label: {
                linkRow("Visit TMDB", systemImage: "safari")
            }
            .buttonStyle(.plain)

            Button {
                showingLicenses = true
            } label: {
                linkRow("Open Source Licenses", systemImage: "doc.text")
            }
            .buttonStyle(.plain)
        }
    }

    private func linkRow(_ title: String, systemImage: String) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
                .foregroundStyle(Palette.textPrimary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Palette.textSecondary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .filmCard()
    }

    private var licensesSheet: some View {
        NavigationStack {
            OpenSourceAttributions()
                .navigationTitle("Licenses")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showingLicenses = false }
                    }
                }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 460)
        #endif
    }
}

#Preview {
    AboutScreen()
        .frame(width: 460, height: 640)
}
