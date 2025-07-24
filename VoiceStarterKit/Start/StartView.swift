import SwiftUI

/// The initial view that is shown when the app is not connected to the server.
struct StartView: View {
    @ObservedObject var viewModel: AppViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @Namespace private var button

    var body: some View {
        VStack(spacing: 8 * .grid) {
            bars()
            connectButton()
        }
        .padding(.horizontal, horizontalSizeClass == .regular ? 32 * .grid : 16 * .grid)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom, content: tip)
        #if os(visionOS)
            .glassBackgroundEffect()
            .frame(maxWidth: 175 * .grid)
        #endif
    }

    @ViewBuilder
    private func bars() -> some View {
        HStack(spacing: .grid * 2) {
            ForEach(0 ..< 2, id: \.self) { _ in
                Rectangle()
                    .fill(.fg0)
                    .frame(width: 14, height: 60)
            }
        }
    }

    @ViewBuilder
    private func tip() -> some View {
        VStack(spacing: 2 * .grid) {
            #if targetEnvironment(simulator)
            Text("connect.simulator")
                .foregroundStyle(.fgModerate)
            #endif
        }
        .font(.system(size: 12))
        .multilineTextAlignment(.center)
        .padding(.horizontal, horizontalSizeClass == .regular ? 32 * .grid : 16 * .grid)
    }

    @ViewBuilder
    private func connectButton() -> some View {
        AsyncButton(action: viewModel.connect) {
            HStack {
                Spacer()
                Text("connect.start")
                    .matchedGeometryEffect(id: "connect", in: button)
                Spacer()
            }
            .frame(width: 58 * .grid, height: 11 * .grid)
        } busyLabel: {
            HStack(spacing: 4 * .grid) {
                Spacer()
                Spinner()
                    .transition(.scale.combined(with: .opacity))
                Text("connect.connecting")
                    .matchedGeometryEffect(id: "connect", in: button)
                Spacer()
            }
            .frame(width: 58 * .grid, height: 11 * .grid)
        }
        #if os(visionOS)
        .buttonStyle(.borderedProminent)
        .controlSize(.extraLarge)
        #else
        .buttonStyle(ProminentButtonStyle())
        #endif
    }
}

#Preview {
    StartView(viewModel: AppViewModel())
}
