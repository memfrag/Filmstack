//
//  Filmstack
//

import SwiftUI

/// Settings screen for the user's bring-your-own TMDB Read Access Token.
///
/// The full token is never shown again after saving — only a masked suffix.
struct TMDBKeySettings: View {

    @State private var model: TMDBKeySettingsModel
    @Environment(AppSettings.self) private var appSettings

    private let tokenURL = URL(string: "https://www.themoviedb.org/settings/api")!

    /// ISO 3166-1 country codes with localized names, sorted by name.
    private let regions: [(code: String, name: String)] = Locale.Region.isoRegions
        .filter { $0.identifier.count == 2 }
        .compactMap { region in
            guard let name = Locale.current.localizedString(forRegionCode: region.identifier) else { return nil }
            return (region.identifier, name)
        }
        .sorted { $0.name < $1.name }

    init(model: TMDBKeySettingsModel = TMDBKeySettingsModel()) {
        _model = State(wrappedValue: model)
    }

    var body: some View {
        @Bindable var model = model
        @Bindable var appSettings = appSettings

        Form {
            Section {
                LabeledContent("Provider", value: "TMDB")
                LabeledContent("Status") { statusBadge }
            } footer: {
                Text("This product uses the TMDB API but is not endorsed or certified by TMDB.")
            }

            Section {
                SecureField("Paste Read Access Token", text: $model.tokenInput)
                    .disableAutocorrection(true)
                HStack {
                    Button(model.isConfigured ? "Replace Key" : "Save Key") {
                        Task { await model.saveToken() }
                    }
                    .disabled(!model.canSave)

                    if model.isBusy {
                        ProgressView().controlSize(.small)
                    }
                }
            } header: {
                Text("API Read Access Token")
            } footer: {
                Link("Get a token from your TMDB account settings", destination: tokenURL)
                    .font(.footnote)
            }

            Section {
                Button("Test Connection") {
                    Task { await model.testConnection() }
                }
                .disabled(!model.isConfigured || model.isBusy)

                Button("Delete Key", role: .destructive) {
                    model.deleteToken()
                }
                .disabled(!model.isConfigured || model.isBusy)
            }

            Section {
                Picker("Region", selection: $appSettings.releaseRegion) {
                    ForEach(regions, id: \.code) { region in
                        Text(region.name).tag(region.code)
                    }
                }
            } header: {
                Text("Release Dates")
            } footer: {
                Text("Used to show the release date for your region when available, "
                     + "falling back to TMDB's primary release date.")
            }

            if let feedback = model.feedback {
                Section {
                    Label(feedback.text, systemImage: feedback.kind == .success
                        ? "checkmark.circle.fill"
                        : "exclamationmark.triangle.fill")
                        .foregroundStyle(feedback.kind == .success ? Color.green : Color.red)
                        .font(.callout)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("TMDB API Key")
        .onAppear { model.refreshStatus() }
    }

    @ViewBuilder private var statusBadge: some View {
        switch model.status {
        case .missing:
            Label("Missing", systemImage: "circle")
                .foregroundStyle(.secondary)
        case .configured(let masked):
            Label("Configured \(masked)", systemImage: "checkmark.seal.fill")
                .foregroundStyle(.green)
        case .invalid:
            Label("Invalid", systemImage: "xmark.seal.fill")
                .foregroundStyle(.red)
        }
    }
}

#if DEBUG
#Preview("Missing") {
    NavigationStack {
        TMDBKeySettings(model: TMDBKeySettingsModel(
            keyStore: InMemoryAPIKeyStore(),
            client: MockMovieAPIClient()
        ))
    }
    .environment(AppSettings.mock())
    .frame(width: 480, height: 420)
}

#Preview("Configured") {
    NavigationStack {
        TMDBKeySettings(model: TMDBKeySettingsModel(
            keyStore: InMemoryAPIKeyStore(token: "abcdEFGHijklMNOPqrstWXYZ1234"),
            client: MockMovieAPIClient()
        ))
    }
    .environment(AppSettings.mock())
    .frame(width: 480, height: 420)
}
#endif
