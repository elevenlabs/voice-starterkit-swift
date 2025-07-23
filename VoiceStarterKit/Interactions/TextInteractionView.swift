import SwiftUI

/// A multiplatform view that shows text-specific interaction controls.
///
/// Depending on the track availability, the view will show:
/// - agent participant view
/// - local participant camera preview
/// - local participant screen share preview
///
/// Additionally, the view shows a complete chat view with text input capabilities.
struct TextInteractionView: View {
    @ObservedObject var viewModel: AppViewModel
    @FocusState.Binding var keyboardFocus: Bool

    var body: some View {
        VStack {
            VStack {
                participants()
                ChatView(viewModel: viewModel)
                #if os(macOS)
                    .frame(maxWidth: 128 * .grid)
                #endif
                    .blurredTop()
            }
            #if os(iOS)
            .contentShape(Rectangle())
            .onTapGesture {
                keyboardFocus = false
            }
            #endif
            ChatTextInputView(viewModel: viewModel, keyboardFocus: _keyboardFocus)
        }
    }

    @ViewBuilder
    private func participants() -> some View {
        HStack {
            Spacer()
            AgentParticipantView(viewModel: viewModel)
                .frame(maxWidth: 25 * .grid)
            Spacer()
        }
        .frame(height: 25 * .grid)
        .safeAreaPadding()
    }
}
