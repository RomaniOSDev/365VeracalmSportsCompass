import SwiftUI

struct DeferredLaunchCanvas: View {
    @ObservedObject var state: LaunchStagingState
    let background: Image?
    let style: StartAppStagingStyle

    private let barWidth: CGFloat = 200
    private let barHeight: CGFloat = 4

    private var clampedProgress: CGFloat {
        CGFloat(min(1.0, max(0.05, state.progress)))
    }

    var body: some View {
        ZStack {
            style.backgroundColor.ignoresSafeArea()

            if let background {
                background
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()
            }

            if !style.overlayColors.isEmpty {
                LinearGradient(
                    colors: style.overlayColors,
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            }

            VStack(spacing: 24) {
                Spacer()

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(style.progressTrackColor)
                    Capsule()
                        .fill(style.progressTint)
                        .frame(width: barWidth * clampedProgress)
                        .animation(.easeInOut(duration: 0.3), value: clampedProgress)
                }
                .frame(width: barWidth, height: barHeight)

                Text(state.statusMessage)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(style.textColor)
                    .multilineTextAlignment(.center)
                    .shadow(color: style.textShadowColor, radius: 2, x: 0, y: 1)
                    .padding(.horizontal, 32)

                Spacer()
                    .frame(height: 80)
            }
        }
    }
}
