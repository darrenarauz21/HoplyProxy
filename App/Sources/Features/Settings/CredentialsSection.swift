import SwiftUI

struct CredentialsSection: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        Section {
            Toggle("settings.auth.toggle", isOn: authenticationBinding)

            if viewModel.authenticationEnabled {
                LabeledContent("settings.auth.username") {
                    TextField("settings.auth.username", text: $viewModel.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("settings.auth.password") {
                    HStack(spacing: 8) {
                        TextField("settings.auth.password", text: $viewModel.password)
                            .font(.callout.monospaced())
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .multilineTextAlignment(.trailing)
                        CopyButton(value: viewModel.password)
                    }
                }
                Button("settings.auth.regenerate", action: viewModel.generateCredentials)
            }
        } header: {
            Text("settings.auth.section")
        } footer: {
            Text("settings.auth.footer")
        }
    }

    private var authenticationBinding: Binding<Bool> {
        Binding(
            get: { viewModel.authenticationEnabled },
            set: { viewModel.setAuthenticationEnabled($0) }
        )
    }
}
