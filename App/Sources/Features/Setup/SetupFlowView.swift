import ProxyConfig
import SwiftUI

struct SetupFlowView: View {
    @StateObject private var model: SetupFlowModel
    @ObservedObject private var controller: ProxyController
    @Environment(\.dismiss) private var dismiss

    init(controller: ProxyController) {
        _model = StateObject(wrappedValue: SetupFlowModel(controller: controller))
        self.controller = controller
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    StepProgress(current: model.stepNumber, total: model.stepCount)
                    stepContent
                }
                .padding(20)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if model.canGoBack {
                        Button(action: model.goBack) {
                            Image(systemName: "chevron.left")
                        }
                        .accessibilityLabel(Text("setup.back"))
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                actionBar
            }
        }
        .tint(Theme.accent)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch model.step {
        case .transport:
            SetupTransportStep(
                selection: $model.transport,
                wifiNetwork: controller.wifiNetwork,
                issues: model.issues,
                didFailToPersist: model.didFailToPersist
            )
        case .laptop:
            SetupLaptopStep(controller: controller)
        case .summary:
            SetupSummaryStep(details: controller.connectionDetails)
        }
    }

    private var actionBar: some View {
        VStack(spacing: 4) {
            if model.step == .summary {
                Button("setup.startProxy") {
                    model.finish(startingProxy: true)
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle())

                Button("setup.finishWithoutStarting") {
                    model.finish(startingProxy: false)
                    dismiss()
                }
                .buttonStyle(QuietButtonStyle())
            } else {
                Button("setup.next", action: model.goForward)
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Theme.background)
    }
}

/// Avance del asistente como segmentos.
private struct StepProgress: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...total, id: \.self) { step in
                Capsule()
                    .fill(step <= current ? Theme.accent : Theme.border)
                    .frame(height: 4)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("setup.progress \(current) \(total)"))
    }
}
