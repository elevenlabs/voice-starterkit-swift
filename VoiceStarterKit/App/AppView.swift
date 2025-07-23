import SwiftUI

struct AppView: View {
    @StateObject private var viewModel = AppViewModel()

    @State private var error: Error?
    @FocusState private var keyboardFocus: Bool
    @State private var interactionMode: AppViewModel.InteractionMode = .voice

    @Namespace private var namespace

    var body: some View {
        ZStack(alignment: .top) {
            if viewModel.isInteractive {
                interactions()
            } else {
                start()
            }

            errors()
        }
        .environment(\.namespace, namespace)
        #if os(visionOS)
            .ornament(attachmentAnchor: .scene(.bottom)) {
                if viewModel.isInteractive {
                    ControlBar(viewModel: viewModel, interactionMode: $interactionMode)
                        .glassBackgroundEffect()
                }
            }
            .alert("warning.reconnecting", isPresented: .constant(viewModel.connectionState == .reconnecting)) {}
            .alert(error?.localizedDescription ?? "error.title", isPresented: .constant(error != nil)) {
                Button("error.ok") { error = nil }
            }
        #else
            .safeAreaInset(edge: .bottom) {
                if viewModel.isInteractive, !keyboardFocus {
                    ControlBar(viewModel: viewModel, interactionMode: $interactionMode)
                        .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
                }
            }
        #endif
            .background(.bg1)
            .animation(.default, value: viewModel.isInteractive)
            .animation(.default, value: interactionMode)
            .animation(.default, value: error?.localizedDescription)
            .onAppear {
                Dependencies.shared.errorHandler = { error = $0 }
            }
        #if os(iOS)
            .sensoryFeedback(.impact, trigger: viewModel.isListening)
        #endif
    }

    @ViewBuilder
    private func start() -> some View {
        StartView(viewModel: viewModel)
    }

    @ViewBuilder
    private func interactions() -> some View {
        #if os(visionOS)
        VisionInteractionView(viewModel: viewModel, keyboardFocus: $keyboardFocus)
            .overlay(alignment: .bottom) {
                agentListening()
                    .padding(16 * .grid)
            }
        #else
        switch interactionMode {
        case .text:
            TextInteractionView(viewModel: viewModel, keyboardFocus: $keyboardFocus)
        case .voice:
            VoiceInteractionView(viewModel: viewModel)
                .overlay(alignment: .bottom) {
                    agentListening()
                        .padding()
                }
        }
        #endif
    }

    @ViewBuilder
    private func errors() -> some View {
        #if !os(visionOS)
        if case .reconnecting = viewModel.connectionState {
            WarningView(warning: "warning.reconnecting")
        }

        if let error {
            ErrorView(error: error) { self.error = nil }
        }
        #endif
    }

    @ViewBuilder
    private func agentListening() -> some View {
        ZStack {
            if viewModel.messages.isEmpty
            {
                AgentListeningView()
            }
        }
        .animation(.default, value: viewModel.messages.isEmpty)
    }
}

#Preview {
    AppView()
}
