import SwiftUI

#if os(visionOS)
/// A platform-specific view that shows all interaction controls with optional chat.
struct VisionInteractionView: View {
    @ObservedObject var viewModel: AppViewModel
    @FocusState.Binding var keyboardFocus: Bool

    var body: some View {
        HStack {
            agent()
            chat()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func agent() -> some View {
        AgentParticipantView(viewModel: viewModel)
            .frame(width: 175 * .grid)
            .frame(maxHeight: .infinity)
            .glassBackgroundEffect()
    }

    @ViewBuilder
    private func chat() -> some View {
        VStack {
            if case .text = viewModel.interactionMode {
                ChatView(viewModel: viewModel)
                ChatTextInputView(viewModel: viewModel, keyboardFocus: _keyboardFocus)
            }
        }
        .frame(width: 125 * .grid)
        .glassBackgroundEffect()
    }
}
#endif
