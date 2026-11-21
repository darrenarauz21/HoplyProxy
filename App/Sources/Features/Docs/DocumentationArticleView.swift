import SwiftUI

struct DocumentationArticleView: View {
    let topic: DocumentationTopic
    let blocks: [DocumentationBlock]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    IconBadge(systemName: topic.systemImage, size: 44)
                    Text(topic.titleKey)
                        .font(Theme.title(.title2))
                        .foregroundStyle(Theme.text)
                }
                .padding(.bottom, 6)

                ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                    DocumentationBlockView(block: block)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct DocumentationBlockView: View {
    let block: DocumentationBlock

    var body: some View {
        switch block {
        case .heading(let key):
            Text(key)
                .font(.headline)
                .foregroundStyle(Theme.text)
                .padding(.top, 8)
        case .paragraph(let key):
            Text(key)
                .font(.body)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        case .bullet(let key):
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(verbatim: "\u{2022}")
                    .font(.body.weight(.bold))
                    .foregroundStyle(Theme.accent)
                    .accessibilityHidden(true)
                Text(key)
                    .font(.body)
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        case .command(let command):
            HStack(alignment: .top, spacing: 8) {
                Text(verbatim: command)
                    .font(.footnote.monospaced())
                    .foregroundStyle(Theme.text)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                CopyButton(value: command)
            }
            .padding(12)
            .background(Theme.raised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Theme.border, lineWidth: 1)
            )
        }
    }
}
