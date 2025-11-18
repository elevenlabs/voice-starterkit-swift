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
        static let publicAgentId: String = "<insert-agent-id-here>"
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
    private var alignmentTask: Task<Void, Never>?
    private var fallbackHighlightTask: Task<Void, Never>?

    // Alert tool state
    @Published var currentAlert: AlertInfo?

    // Word highlighting state
    @Published var highlightedMessageId: String?
    @Published var highlightedCharacterCount: Int = 0

    // Diagnostics
    @Published var startupState: ConversationStartupState = .idle
    @Published var startupMetrics: ConversationStartupMetrics?
    @Published var eventLogs: [String] = []

    // Audio pipeline controls
    @Published var micVolume: Double
    @Published var voiceProcessingBypassed: Bool
    @Published var agcEnabled: Bool
    @Published var recordingAlwaysPrepared: Bool
    @Published var microphoneMuteMode: MicrophoneMuteMode

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

    private var lastLoggedMessageCount = 0

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

        let audioManager = AudioManager.shared
        micVolume = Double(audioManager.mixer.micVolume)
        voiceProcessingBypassed = audioManager.isVoiceProcessingBypassed
        agcEnabled = audioManager.isVoiceProcessingAGCEnabled
        recordingAlwaysPrepared = audioManager.isRecordingAlwaysPreparedMode
        microphoneMuteMode = audioManager.microphoneMuteMode
    }

    private func resetState() {
        interactionMode = .voice
        highlightedMessageId = nil
        highlightedCharacterCount = 0
        alignmentTask?.cancel()
        fallbackHighlightTask?.cancel()
        fallbackHighlightTask = nil
        alignmentTask = nil
        cancellables.removeAll()
        conversation = nil
        startupState = .idle
        startupMetrics = nil
    }

    // MARK: - Connection

    func connect() async {
        errorHandler(nil)
        resetState()
        do {
            let auth = ElevenLabsConfiguration.publicAgent(id: Constants.publicAgentId)
            let config = makeConversationConfig()
            let newConversation = try await ElevenLabs.startConversation(auth: auth, config: config)
            conversation = newConversation

            // Observe specific conversation changes for immediate UI updates
            newConversation.$state.sink { [weak self] state in
                guard let self else { return }
                objectWillChange.send()
                log("Conversation state -> \(String(describing: state))")
                if case let .error(error) = state {
                    log("Conversation entered error state: \(error.localizedDescription)")
                }
                if case .ended = state {
                    log("Conversation ended; cleaning up")
                }
            }.store(in: &cancellables)

            newConversation.$messages.sink { [weak self] messages in
                guard let self else { return }
                objectWillChange.send()
                if messages.count != lastLoggedMessageCount {
                    lastLoggedMessageCount = messages.count
                    if let last = messages.last {
                        log("Message #\(messages.count) [\(last.role)] => \(last.content.prefix(80))")
                    } else {
                        log("Messages cleared")
                    }
                }
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

            newConversation.$latestAudioEvent
                .compactMap(\.self)
                .sink { [weak self] audioEvent in
                    self?.handleAudioEvent(audioEvent)
                }
                .store(in: &cancellables)

            newConversation.$startupMetrics
                .sink { [weak self] metrics in
                    self?.startupMetrics = metrics
                    self?.log("Startup metrics updated: attempts=\(metrics?.conversationInitAttempts ?? 0)")
                }
                .store(in: &cancellables)

            await applyAudioSettings()
        } catch {
            errorHandler(error)
            log("Connection failed: \(error.localizedDescription)")
            resetState()
        }
    }

    func disconnect() async {
        await conversation?.endConversation()
        conversation = nil
        resetState()
    }

    func highlightedCharacterCount(for message: Message) -> Int {
        guard message.id == highlightedMessageId else { return 0 }
        return min(highlightedCharacterCount, message.content.count)
    }

    // MARK: - Diagnostics

    func applyAudioSettings() async {
        // Perform immediate, synchronous updates on the main actor without awaiting
        let micVolume = self.micVolume
        let voiceProcessingBypassed = self.voiceProcessingBypassed
        let agcEnabled = self.agcEnabled
        let recordingAlwaysPrepared = self.recordingAlwaysPrepared
        let microphoneMuteMode = self.microphoneMuteMode

        // Apply non-suspending property updates first
        do {
            let audioManager = AudioManager.shared
            audioManager.mixer.micVolume = Float(micVolume)
            audioManager.isVoiceProcessingBypassed = voiceProcessingBypassed
            audioManager.isVoiceProcessingAGCEnabled = agcEnabled
        }

        // Reacquire the singleton across suspension boundaries to avoid sending a non-Sendable reference
        do {
            try? await AudioManager.shared.setRecordingAlwaysPreparedMode(recordingAlwaysPrepared)
            try? AudioManager.shared.set(microphoneMuteMode: microphoneMuteMode)
        }

        log("Audio settings updated: micVolume=\(String(format: "%.2f", micVolume)), bypass=\(voiceProcessingBypassed), AGC=\(agcEnabled), prepared=\(recordingAlwaysPrepared), muteMode=\(String(describing: microphoneMuteMode))")
    }

    func setMicrophoneMode(_ mode: MicrophoneMuteMode) async {
        microphoneMuteMode = mode
        await applyAudioSettings()
    }

    func log(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let entry = "[\(timestamp)] \(message)"
        print("[VoiceStarterKit] \(entry)")
        eventLogs.append(entry)
        if eventLogs.count > 20 {
            eventLogs.removeFirst(eventLogs.count - 20)
        }
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

    private func handleAudioEvent(_ audioEvent: AudioEvent) {
        guard let conversation else {
            log("Audio event arrived before conversation available")
            return
        }

        guard let message = conversation.messages.last(where: { $0.role == .agent }) else {
            log("Audio event received but no agent transcript yet")
            return
        }

        if audioEvent.alignment == nil {
            log("Audio event for message \(String(message.id.prefix(6))) missing alignment data – falling back to static highlight")
            highlightEntireMessage(message)
            return
        }

        guard let alignment = audioEvent.alignment else { return }

        alignmentTask?.cancel()
        fallbackHighlightTask?.cancel()
        fallbackHighlightTask = nil

        let text = message.content
        let charCount = min(
            text.count,
            alignment.chars.count,
            alignment.charStartTimesMs.count,
            alignment.charDurationsMs.count
        )

        guard charCount > 0 else {
            log("Alignment did not contain any characters for message \(String(message.id.prefix(6))) – highlighting fallback")
            highlightEntireMessage(message)
            return
        }

        alignmentTask = Task { [weak self] in
            guard let self else { return }

            await MainActor.run {
                self.highlightedMessageId = message.id
                self.highlightedCharacterCount = 0
            }

            var previousEndMs = 0
            var currentIndex = text.startIndex
            let preview = alignment.chars.prefix(6).joined(separator: "")
            log("Alignment received (message: \(String(message.id.prefix(6)))) preview=\(preview)")

            for index in 0 ..< charCount {
                if Task.isCancelled { return }

                let startMs = alignment.charStartTimesMs[index]
                let durationMs = alignment.charDurationsMs[index]
                let waitMs = max(startMs - previousEndMs, 0)

                if waitMs > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(waitMs) * 1_000_000)
                }

                if Task.isCancelled { return }

                await MainActor.run {
                    if self.highlightedMessageId == message.id {
                        let segment = alignment.chars[index]
                        if let range = text[currentIndex...].range(of: segment) {
                            currentIndex = range.upperBound
                        } else if currentIndex < text.endIndex {
                            currentIndex = text.index(after: currentIndex)
                        }
                        let distance = text.distance(from: text.startIndex, to: currentIndex)
                        self.highlightedCharacterCount = min(distance, text.count)
                        if index % 5 == 0 {
                            self.log("Highlight progress: \(self.highlightedCharacterCount)/\(text.count) characters")
                        }
                    }
                }

                previousEndMs = startMs + durationMs
            }

            // Allow the highlight to linger briefly, then clear.
            try? await Task.sleep(nanoseconds: 400_000_000)

            await MainActor.run {
                if self.highlightedMessageId == message.id {
                    self.highlightedMessageId = nil
                    self.highlightedCharacterCount = 0
                }
                self.alignmentTask = nil
                self.log("Highlight completed for message \(String(message.id.prefix(6)))")
            }
        }
    }

    private func highlightEntireMessage(_ message: Message, duration: TimeInterval = 1.2) {
        fallbackHighlightTask?.cancel()
        fallbackHighlightTask = Task { [weak self] in
            guard let self else { return }
            let text = message.content

            await MainActor.run {
                self.highlightedMessageId = message.id
                self.highlightedCharacterCount = text.count
            }

            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))

            await MainActor.run {
                if self.highlightedMessageId == message.id {
                    self.highlightedMessageId = nil
                    self.highlightedCharacterCount = 0
                }
                self.fallbackHighlightTask = nil
            }
        }
    }

    private func makeConversationConfig() -> ConversationConfig {
        let audioConfig = AudioPipelineConfiguration(
            microphoneMuteMode: microphoneMuteMode,
            recordingAlwaysPrepared: recordingAlwaysPrepared,
            voiceProcessingBypassed: voiceProcessingBypassed,
            voiceProcessingAGCEnabled: agcEnabled
        )

        return ConversationConfig(
            onStartupStateChange: { [weak self] state in
                Task { @MainActor in
                    self?.startupState = state
                    self?.log("Startup state -> \(String(describing: state))")
                }
            },
            audioConfiguration: audioConfig,
            onError: { [weak self] error in
                Task { @MainActor in
                    self?.log("⚠️ SDK ERROR: \(error.localizedDescription)")
                    // Also trigger the global error handler for banner display
                    self?.errorHandler(error)
                }
            },
            onAgentResponse: { [weak self] _, eventId in
                Task { @MainActor in self?.log("Agent response eventId=\(eventId)") }
            },
            onUserTranscript: { [weak self] transcript, _ in
                Task { @MainActor in self?.log("User transcript -> \(transcript.prefix(80))") }
            },
            onAudioAlignment: { [weak self] alignment in
                Task { @MainActor in self?.log("Alignment callback chars=\(alignment.chars.count)") }
            }
        )
    }
}

