import SwiftUI

/// Opciones de funcionamiento de la app: segundo plano y recordatorio de renovación.
struct BehaviorSection: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        Section {
            Toggle("settings.behavior.background", isOn: $viewModel.keepsRunningInBackground)
            if viewModel.canRemindBeforeSignatureExpiry {
                Toggle("settings.behavior.reminder", isOn: $viewModel.remindsBeforeSignatureExpiry)
            }
        } header: {
            Text("settings.behavior.section")
        } footer: {
            Text("settings.behavior.footer")
        }
    }
}
