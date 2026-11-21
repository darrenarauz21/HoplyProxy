import ProxyConfig
import ProxyCore
import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss

    init(controller: ProxyController) {
        _viewModel = StateObject(wrappedValue: SettingsViewModel(controller: controller))
    }

    var body: some View {
        NavigationStack {
            Form {
                connectionSection

                if viewModel.transport == .wifi {
                    AllowedClientsSection(viewModel: viewModel)
                }

                CredentialsSection(viewModel: viewModel)

                limitsSection

                BehaviorSection(viewModel: viewModel)

                if !viewModel.issues.isEmpty || viewModel.didFailToPersist {
                    Section {
                        ValidationMessagesView(issues: viewModel.issues, showsPersistenceError: viewModel.didFailToPersist)
                    }
                }

                if viewModel.isServerActive {
                    Section {
                        Text("settings.restartNotice")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("settings.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save") {
                        if viewModel.save() {
                            dismiss()
                        }
                    }
                }
            }
            .onAppear(perform: viewModel.refreshNetwork)
        }
    }

    private var connectionSection: some View {
        Section("settings.connection.section") {
            Picker("settings.transport", selection: $viewModel.transport) {
                ForEach(TransportMode.allCases, id: \.self) { mode in
                    Text(mode.titleKey).tag(mode)
                }
            }
            LabeledContent("settings.port") {
                TextField("settings.port", value: $viewModel.port, format: .number.grouping(.never))
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    private var limitsSection: some View {
        Section("settings.limits.section") {
            Stepper(value: $viewModel.maximumConnections, in: ProxyServerConfiguration.maximumConnectionsRange) {
                LabeledContent("settings.maximumConnections") {
                    Text(viewModel.maximumConnections, format: .number)
                }
            }
            Stepper(
                value: $viewModel.idleTimeoutSeconds,
                in: SettingsViewModel.idleTimeoutRange,
                step: SettingsViewModel.idleTimeoutStep
            ) {
                LabeledContent("settings.idleTimeout") {
                    Text("settings.seconds \(viewModel.idleTimeoutSeconds)")
                }
            }
        }
    }
}
