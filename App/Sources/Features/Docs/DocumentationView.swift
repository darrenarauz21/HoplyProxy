import SwiftUI

/// Índice de la documentación: lo que la pantalla principal y el asistente no explican en detalle.
struct DocumentationView: View {
    @ObservedObject var controller: ProxyController

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("docs.intro")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
                    .padding(.horizontal, 4)

                Card {
                    ForEach(Array(DocumentationTopic.allCases.enumerated()), id: \.offset) { index, topic in
                        if index > 0 {
                            Divider()
                        }
                        NavigationLink {
                            destination(for: topic)
                        } label: {
                            NavigationRow(titleKey: topic.titleKey, systemImage: topic.systemImage, detailKey: topic.summaryKey)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(20)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("docs.title")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func destination(for topic: DocumentationTopic) -> some View {
        if topic == .manualSetup {
            ClientGuideView(controller: controller)
        } else {
            DocumentationArticleView(
                topic: topic,
                blocks: DocumentationContent.blocks(for: topic, details: controller.connectionDetails)
            )
        }
    }
}
