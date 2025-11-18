import ElevenLabs
import SwiftUI

// Use ElevenLabs Message type directly

/// A multiplatform view that shows the message feed.
struct ChatView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        ScrollViewReader { scrollView in
            List {
                ForEach(viewModel.messages.reversed(), id: \.id, content: message)
            }
            .onChange(of: viewModel.messages.count) {
                withAnimation(.smooth) {
                    scrollView.scrollTo(viewModel.messages.last?.id)
                }
            }
        }
        .upsideDown()
        .listStyle(.plain)
        .scrollIndicators(.never)
        .scrollContentBackground(.hidden)
        .animation(.default, value: viewModel.messages.count)
    }

    @ViewBuilder
    private func message(_ message: Message) -> some View {
        ZStack {
            switch message.role {
            case .user:
                userTranscript(message.content)
            case .agent:
                agentTranscript(message)
            }
        }
        .upsideDown()
        .listRowBackground(EmptyView())
        .listRowSeparator(.hidden)
        .id(message.id) // for the ScrollViewReader to work
    }

    @ViewBuilder
    private func userTranscript(_ text: String) -> some View {
        HStack {
            Spacer(minLength: 4 * .grid)
            Text(text.trimmingCharacters(in: .whitespacesAndNewlines))
                .font(.system(size: 17))
                .padding(.horizontal, 4 * .grid)
                .padding(.vertical, 2 * .grid)
                .foregroundStyle(.fg1)
                .background(
                    RoundedRectangle(cornerRadius: .cornerRadiusLarge)
                        .fill(.bg2)
                )
        }
    }

    @ViewBuilder
    private func agentTranscript(_ message: Message) -> some View {
        let text = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        let highlightedCount = min(viewModel.highlightedCharacterCount(for: message), text.count)
        let highlightIndex = text.index(text.startIndex, offsetBy: highlightedCount, limitedBy: text.endIndex) ?? text.endIndex
        let highlighted = String(text[..<highlightIndex])
        let remainder = String(text[highlightIndex...])
        let highlightedText = Text(highlighted)
            .foregroundColor(.accentColor)
            .font(.system(size: 17, weight: .semibold))
        let remainderText = Text(remainder)
            .foregroundStyle(.fg1)
            .font(.system(size: 17))

        HStack(alignment: .top) {
            // Build the concatenated Text first to satisfy the `+` operator requirements
            let leading: Text = highlighted.isEmpty ? Text("") : Text(highlighted)
            let combined: Text = leading.foregroundStyle(.fgAccent).font(.system(size: 17, weight: .semibold)) + Text(remainder).foregroundStyle(.fg1).font(.system(size: 17))

            combined
                .padding(.vertical, 2 * .grid)

            Spacer(minLength: 4 * .grid)
        }
    }
}
