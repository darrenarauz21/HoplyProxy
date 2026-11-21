import ProxyConfig
import SwiftUI

struct ClientPlatformPicker: View {
    @Binding var selection: ClientPlatform

    var body: some View {
        Picker("guide.platform", selection: $selection) {
            ForEach(ClientPlatform.allCases, id: \.self) { platform in
                Text(verbatim: platform.displayName).tag(platform)
            }
        }
        .pickerStyle(.segmented)
    }
}
