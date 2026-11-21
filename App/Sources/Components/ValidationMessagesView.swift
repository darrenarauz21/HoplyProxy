import ProxyConfig
import SwiftUI

struct ValidationMessagesView: View {
    let issues: [ProxySettingsIssue]
    var showsPersistenceError = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(issues, id: \.self) { issue in
                Label {
                    Text(issue.messageKey)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                }
            }
            if showsPersistenceError {
                Label {
                    Text("issue.persistence")
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                }
            }
        }
        .font(.footnote)
        .foregroundStyle(Theme.danger)
    }
}
