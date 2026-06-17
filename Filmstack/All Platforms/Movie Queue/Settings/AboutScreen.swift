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
                privacyNote
                links
            }
            .padding(24)
            .frame(maxWidth: 460)
            .frame(maxWidth: .infinity)
        }
        .background(Palette.base)
        .navigationTitle("About")
        .sheet(isPresented: $showingLicenses) {
            licensesSheet
        }
    }

    // MARK: - Sections

    private var appHeader: some View {
        VStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Gradients.accentButton)
                .frame(width: 88, height: 88)
                .overlay {
                    Image(systemName: "film.stack.fill")
                        .font(.system(size: 40, weight: .medium))
                        .foregroundStyle(.white)
                }
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

            HStack(spacing: 12) {
                Text("TMDB")
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 14)
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
                Spacer()
            }

            Text(tmdbAttribution)
                .font(.footnote)
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .filmCard()
    }

    private var privacyNote: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PRIVACY")
                .font(.caption.bold())
                .foregroundStyle(Palette.accentBright)
            Text("""
            Filmstack is for personal, non-commercial use. There's no account, \
            backend, or analytics. Your movie library is stored locally on this \
            device, and your TMDB token is kept in the system Keychain.
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
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showingLicenses = false }
                    }
                }
        }
        .frame(minWidth: 420, minHeight: 460)
    }
}

#Preview {
    AboutScreen()
        .frame(width: 460, height: 640)
}
