@preconcurrency import AVFoundation
import Combine
import ElevenLabs
import LiveKit
import Observation

// Use ElevenLabs Message type directly

struct AlertInfo: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let toolCallId: String
}

@MainActor
final class AppViewModel: ObservableObject {
    // MARK: - Constants

    private enum Constants {
        static let publicAgentId: String = "insert_your_agent_id_here"
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

    // Alert tool state
    @Published var currentAlert: AlertInfo?

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
        guard let conversation else { return false }
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

            newConversation.$pendingToolCalls.sink { [weak self] toolCalls in
                for toolCall in toolCalls {
                    print("Received client tool call: \(toolCall.toolName) (ID: \(toolCall.toolCallId))")
                    Task {
                        await self?.handleToolCall(toolCall)
                    }
                }
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
    func select(audioDevice _: AudioDevice) {
        // Audio device selection handled by ElevenLabs SDK internally
        // This method kept for UI compatibility
    }
    #endif

    func switchCamera() async {
        // Camera switching not directly supported in ElevenLabs SDK
        // TODO: Implement if needed for your use case
    }

    // MARK: - Example Client Tool Call Handling with user response expected

    /// This is an example of how to handle tool calls, a client tool called `alert_tool` must be added to the agent. This tool must expect a response.
    private func handleToolCall(_ toolCall: ClientToolCallEvent) async {
        do {
            let parameters = try toolCall.getParameters()

            switch toolCall.toolName {
            case "alert_tool":
                await handleAlertTool(toolCall: toolCall, parameters: parameters)
            default:
                try await conversation?.sendToolResult(
                    for: toolCall.toolCallId,
                    result: "Unknown tool: \(toolCall.toolName)",
                    isError: true
                )
                
            }
        } catch {
            try? await conversation?.sendToolResult(
                for: toolCall.toolCallId,
                result: error.localizedDescription,
                isError: true
            )
        }
    }

    private func handleAlertTool(toolCall: ClientToolCallEvent, parameters: [String: Any]) async {
        let title = parameters["title"] as? String ?? "Alert"
        let message = parameters["message"] as? String ?? ""

        currentAlert = AlertInfo(
            title: title,
            message: message,
            toolCallId: toolCall.toolCallId
        )
    }

    func respondToAlert(accepted: Bool) async {
        guard let alert = currentAlert else { return }

        do {
            try await conversation?.sendToolResult(
                for: alert.toolCallId,
                result: accepted ? "User clicked Accept" : "User clicked Decline"
            )
        } catch {
            errorHandler(error)
        }

        currentAlert = nil
    }
}
