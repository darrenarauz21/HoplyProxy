import ProxyConfig
import SwiftUI

/// Pasos numerados para configurar la laptop, con los valores listos para copiar.
struct ClientGuideStepsSection: View {
    let steps: [ClientSetupStep]

    var body: some View {
        Section("guide.steps.section") {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                InstructionStepRow(number: index + 1, textKey: step.instructionKey)
                if let value = step.copyValue {
                    CopyableCommandRow(command: value)
                }
            }
        }
    }
}
