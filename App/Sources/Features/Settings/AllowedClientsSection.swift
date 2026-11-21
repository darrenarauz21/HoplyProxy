import SwiftUI

/// Equipos o redes que pueden usar el proxy en modo Wi-Fi.
struct AllowedClientsSection: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        Section {
            ForEach(viewModel.allowedClients, id: \.self) { entry in
                Text(verbatim: entry)
                    .font(.body.monospaced())
            }
            .onDelete(perform: viewModel.removeAllowedClients)

            HStack {
                TextField("settings.clients.placeholder", text: $viewModel.newAllowedClient)
                    .keyboardType(.numbersAndPunctuation)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit(viewModel.addAllowedClient)
                Button("settings.clients.add", action: viewModel.addAllowedClient)
                    .disabled(!viewModel.canAddAllowedClient)
            }

            if let suggestedSubnet = viewModel.suggestedSubnet {
                Button {
                    viewModel.addSuggestedSubnet()
                } label: {
                    Text("settings.clients.addSuggested \(suggestedSubnet)")
                }
            }
        } header: {
            Text("settings.clients.section")
        } footer: {
            Text("settings.clients.footer")
        }
    }
}
