//
//  Filmstack
//

import SwiftUI

/// Settings screen for the user's bring-your-own TMDB Read Access Token.
///
/// The full token is never shown again after saving — only a masked suffix.
struct TMDBKeySettings: View {

    @State private var model: TMDBKeySettingsModel

    private let tokenURL = URL(string: "https://www.themoviedb.org/settings/api")!

    init(model: TMDBKeySettingsModel = TMDBKeySettingsModel()) {
        _model = State(wrappedValue: model)
    }

    var body: some View {
        @Bindable var model = model

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

#Preview("Missing") {
    NavigationStack {
        TMDBKeySettings(model: TMDBKeySettingsModel(
            keyStore: InMemoryAPIKeyStore(),
            client: MockMovieAPIClient()
        ))
    }
    .frame(width: 480, height: 420)
}

#Preview("Configured") {
    NavigationStack {
        TMDBKeySettings(model: TMDBKeySettingsModel(
            keyStore: InMemoryAPIKeyStore(token: "abcdEFGHijklMNOPqrstWXYZ1234"),
            client: MockMovieAPIClient()
        ))
    }
    .frame(width: 480, height: 420)
}
