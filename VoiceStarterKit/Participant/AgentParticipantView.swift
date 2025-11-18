import ElevenLabsComponents

/// A view that combines the avatar camera view (if available)
/// or the audio visualizer (if available).
/// - Note: If both are unavailable, the view will show a placeholder visualizer.
struct AgentParticipantView: View {
    @ObservedObject var viewModel: AppViewModel
    @Environment(\.namespace) private var namespace

    /// Reveals the avatar camera view when true.
    @SceneStorage("videoTransition") private var videoTransition = false

    var body: some View {
        ZStack {
            if let agentAudioTrack = viewModel.agentAudioTrack {
                OrbVisualizer(inputTrack: agentAudioTrack,
                              outputTrack: agentAudioTrack,
                              agentState: .listening)
                    .frame(maxWidth: 50 * .grid, maxHeight: 50 * .grid)
                    .transition(.opacity)
            } else if viewModel.isInteractive {
                OrbVisualizer(inputTrack: nil,
                              outputTrack: nil,
                              agentState: .listening)
                    .frame(maxWidth: 48 * .grid, maxHeight: 48 * .grid)
                    .transition(.opacity)
            }
        }
        .animation(.snappy, value: viewModel.agentAudioTrack?.id)
        .matchedGeometryEffect(id: "agent", in: namespace!)
    }
}
