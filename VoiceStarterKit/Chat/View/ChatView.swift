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
                agentTranscript(message.content)
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
    private func agentTranscript(_ text: String) -> some View {
        HStack {
            Text(text.trimmingCharacters(in: .whitespacesAndNewlines))
                .font(.system(size: 17))
                .padding(.vertical, 2 * .grid)
            Spacer(minLength: 4 * .grid)
        }
    }
}
