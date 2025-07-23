@preconcurrency import AVFoundation
import Combine
import ElevenLabs
import LiveKit
import Observation

// Use ElevenLabs Message type directly

@MainActor
final class AppViewModel: ObservableObject {
    // MARK: - Constants
    private enum Constants {
        static let publicAgentId: String = "REPLACE_WITH_YOUR_PUBLIC_AGENT_ID"
    }
    

    // MARK: - Modes

    enum InteractionMode {
        case voice
        case text
    }

    let agentFeatures: AgentFeatures

    // MARK: - State

    private(set) var conversation: Conversation?
    private var cancellables = Set<AnyCancellable>()
    
    // Map ElevenLabs conversation state to UI-friendly properties
    var connectionState: ConnectionState {
        guard let conversation else { return .disconnected }
        switch conversation.state {
        case .idle: return .disconnected
        case .connecting: return .connecting
        case .active: return .connected
        case .ended: return .disconnected
        case .error: return .disconnected
        }
    }
    
    var isListening: Bool {
        conversation?.agentState == .listening
    }
    
    var isInteractive: Bool {
        guard let conversation = conversation else { return false }
        switch conversation.state {
        case .active: return true
        default: return false
        }
    }

    private(set) var interactionMode: InteractionMode = .voice
    
    // Messages from conversation
    var messages: [Message] {
        conversation?.messages ?? []
    }

    // MARK: Tracks

    var isMicrophoneEnabled: Bool {
        !(conversation?.isMuted ?? true)
    }
    
    var audioTrack: LocalAudioTrack? {
        conversation?.inputTrack
    }
    
    var agentAudioTrack: RemoteAudioTrack? {
        conversation?.agentAudioTrack
    }

    // MARK: Devices

    var audioDevices: [AudioDevice] {
        conversation?.audioDevices ?? []
    }
    
    var selectedAudioDeviceID: String {
        conversation?.selectedAudioDeviceID ?? ""
    }

    // MARK: - Dependencies

    @Dependency(\.errorHandler) private var errorHandler

    // MARK: - Initialization

    init(agentFeatures: AgentFeatures = .current) {
        self.agentFeatures = agentFeatures
    }

    private func resetState() {
        interactionMode = .voice
    }

    // MARK: - Connection

    func connect() async {
        errorHandler(nil)
        resetState()
        do {
            let newConversation = try await ElevenLabs.startConversation(agentId: Constants.publicAgentId)
            conversation = newConversation
            
            // Observe specific conversation changes for immediate UI updates
            newConversation.$state.sink { [weak self] _ in
                self?.objectWillChange.send()
            }.store(in: &cancellables)
            
            newConversation.$messages.sink { [weak self] _ in
                self?.objectWillChange.send()
            }.store(in: &cancellables)
            
            newConversation.$agentState.sink { [weak self] _ in
                self?.objectWillChange.send()
            }.store(in: &cancellables)
            
            newConversation.$isMuted.sink { [weak self] _ in
                self?.objectWillChange.send()
            }.store(in: &cancellables)
        } catch {
            errorHandler(error)
            resetState()
        }
    }




    func disconnect() async {
        await conversation?.endConversation()
        conversation = nil
        resetState()
    }


    // MARK: - Actions

    func toggleTextInput() {
        switch interactionMode {
        case .voice:
            interactionMode = .text
        case .text:
            interactionMode = .voice
        }
    }
    
    func sendMessage(_ text: String) async {
        do {
            try await conversation?.sendMessage(text)
        } catch {
            errorHandler(error)
        }
    }

    func toggleMicrophone() async {
        do {
            try await conversation?.toggleMute()
        } catch {
            errorHandler(error)
        }
    }


    #if os(macOS)
    func select(audioDevice: AudioDevice) {
        // Audio device selection handled by ElevenLabs SDK internally
        // This method kept for UI compatibility
    }
    #endif

    func switchCamera() async {
        // Camera switching not directly supported in ElevenLabs SDK
        // TODO: Implement if needed for your use case
    }
}
