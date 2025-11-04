import ElevenLabs
import SwiftUI

/// A multiplatform view that shows voice-specific interaction controls.
///
/// Depending on the track availability, the view will show:
/// - agent participant view
/// - local participant camera preview
/// - local participant screen share preview
///
/// - Note: The layout is determined by the horizontal size class.
struct VoiceInteractionView: View {
    @ObservedObject var viewModel: AppViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showDiagnostics = false

    var body: some View {
        if horizontalSizeClass == .regular {
            regular()
        } else {
            compact()
        }
    }

    @ViewBuilder
    private func regular() -> some View {
        ZStack(alignment: .topTrailing) {
            HStack {
                Spacer()
                    .frame(width: 50 * .grid)
                AgentParticipantView(viewModel: viewModel)
                VStack {
                    Spacer()
                }
                .frame(width: 50 * .grid)
            }
            .safeAreaPadding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: 12) {
                diagnosticsToggleButton()
                if showDiagnostics {
                    DiagnosticsPanel(viewModel: viewModel, onDismiss: { showDiagnostics = false })
                        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private func compact() -> some View {
        ZStack(alignment: .topTrailing) {
            ZStack(alignment: .bottom) {
                AgentParticipantView(viewModel: viewModel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea()
                HStack {
                    Spacer()
                }
                .frame(height: 50 * .grid)
                .safeAreaPadding()
            }

            VStack(spacing: 12) {
                diagnosticsToggleButton()
                if showDiagnostics {
                    DiagnosticsPanel(viewModel: viewModel, onDismiss: { showDiagnostics = false })
                        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private func diagnosticsToggleButton() -> some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                showDiagnostics.toggle()
            }
        } label: {
            Image(systemName: showDiagnostics ? "chart.bar.fill" : "chart.bar")
                .font(.system(size: 20))
                .foregroundStyle(.fg1)
                .frame(width: 44, height: 44)
                .background(.thinMaterial, in: Circle())
                .shadow(radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

private struct DiagnosticsPanel: View {
    @ObservedObject var viewModel: AppViewModel
    let onDismiss: () -> Void

    private let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 3
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("SDK Diagnostics")
                    .font(.headline)
                Spacer()
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.fg2)
                }
                .buttonStyle(.plain)
            }

            if viewModel.isInteractive {
                StartupMetricsCard(viewModel: viewModel, formatter: formatter)
                Divider()
            }
            AudioSettingsCard(viewModel: viewModel)
            Divider()
            DiagnosticsLogCard(viewModel: viewModel)
        }
        .padding(12)
        .frame(width: 350)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(radius: 8, x: 0, y: 4)
    }
}

private struct StartupMetricsCard: View {
    @ObservedObject var viewModel: AppViewModel
    let formatter: NumberFormatter

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Startup Diagnostics")
                .font(.headline)
            Text("State: \(String(describing: viewModel.startupState))")
                .font(.caption)
                .foregroundStyle(.fg2)

            if let metrics = viewModel.startupMetrics {
                metricRow("Total", metrics.total)
                metricRow("Token", metrics.tokenFetch)
                metricRow("Room", metrics.roomConnect)
                metricRow("Agent", metrics.agentReady)
                metricRow("Init", metrics.conversationInit)
                Text("Attempts: \(metrics.conversationInitAttempts)")
                    .font(.caption2)
                    .foregroundStyle(.fg3)
            } else {
                Text("Waiting for metrics…")
                    .font(.caption2)
                    .foregroundStyle(.fg3)
            }
        }
    }

    private func metricRow(_ title: String, _ value: TimeInterval?) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(valueString(value))
        }
        .font(.caption2)
        .foregroundStyle(.fg2)
    }

    private func valueString(_ value: TimeInterval?) -> String {
        guard let value else { return "—" }
        let number = NSNumber(value: value)
        return formatter.string(from: number) ?? String(format: "%.3f", value)
    }
}

private struct AudioSettingsCard: View {
    @ObservedObject var viewModel: AppViewModel

    private let modes: [ElevenLabs.MicrophoneMuteMode] = [.voiceProcessing, .restart, .inputMixer]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Audio Controls")
                .font(.headline)

            Slider(value: $viewModel.micVolume, in: 0 ... 1) {
                Text("Mic Volume")
            } minimumValueLabel: {
                Text("0")
                    .font(.caption2)
            } maximumValueLabel: {
                Text("1")
                    .font(.caption2)
            }
            .onChange(of: viewModel.micVolume) { _ in viewModel.applyAudioSettings() }
            Text("Current: \(String(format: "%.2f", viewModel.micVolume))")
                .font(.caption2)
                .foregroundStyle(.fg3)

            Toggle("Bypass Voice Processing", isOn: $viewModel.voiceProcessingBypassed)
                .onChange(of: viewModel.voiceProcessingBypassed) { _ in viewModel.applyAudioSettings() }

            Toggle("Enable AGC", isOn: $viewModel.agcEnabled)
                .onChange(of: viewModel.agcEnabled) { _ in viewModel.applyAudioSettings() }

            Toggle("Keep Mic Warm", isOn: $viewModel.recordingAlwaysPrepared)
                .onChange(of: viewModel.recordingAlwaysPrepared) { _ in viewModel.applyAudioSettings() }

            Picker("Mute Mode", selection: $viewModel.microphoneMuteMode) {
                ForEach(modes, id: \.self) { mode in
                    Text(modeDisplayName(mode)).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: viewModel.microphoneMuteMode) { mode in
                viewModel.setMicrophoneMode(mode)
            }
        }
        .font(.caption)
    }

    private func modeDisplayName(_ mode: ElevenLabs.MicrophoneMuteMode) -> String {
        switch mode {
        case .voiceProcessing: return "Voice"
        case .restart: return "Restart"
        case .inputMixer: return "Mixer"
        case .unknown: return "Auto"
        @unknown default: return "?"
        }
    }
}

private struct DiagnosticsLogCard: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Event Log")
                .font(.headline)

            if viewModel.eventLogs.isEmpty {
                Text("No events yet.")
                    .font(.caption2)
                    .foregroundStyle(.fg3)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(viewModel.eventLogs.suffix(8).reversed(), id: \.self) { entry in
                            HStack(alignment: .top, spacing: 4) {
                                if isErrorEntry(entry) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.caption2)
                                        .foregroundStyle(.fgSerious)
                                } else {
                                    Image(systemName: "circle.fill")
                                        .font(.system(size: 4))
                                        .foregroundStyle(.fg3)
                                }
                                Text(entry)
                                    .font(.caption2)
                                    .foregroundStyle(isErrorEntry(entry) ? .fgSerious : .fg2)
                                    .lineLimit(3)
                            }
                            .padding(.vertical, 2)
                            .padding(.horizontal, 6)
                            .background(isErrorEntry(entry) ? Color.bgSerious.opacity(0.1) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
        }
    }

    private func isErrorEntry(_ entry: String) -> Bool {
        entry.lowercased().contains("error") ||
            entry.lowercased().contains("failed") ||
            entry.lowercased().contains("timeout")
    }
}
