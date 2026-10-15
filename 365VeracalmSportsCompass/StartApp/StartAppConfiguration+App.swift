import StartAppKit
import SwiftUI

extension StartAppConfiguration {

    static var app: StartAppConfiguration {
        StartAppConfiguration(
            calendarGateAnchor: StartAppSecrets.calendarGateAnchor,
            remoteEntryTemplate: StartAppSecrets.remoteFlowEntryTemplate,
            stagingMessage: "Loading...",
            stagingStyle: StartAppStagingStyle(
                backgroundColor: Color("AppBackground"),
                overlayColors: [
                    Color("AppBackground").opacity(0.2),
                    Color("AppBackground").opacity(0.55)
                ],
                progressTint: Color("AppPrimary"),
                progressTrackColor: Color("AppPrimary").opacity(0.25),
                textColor: .primary,
                textShadowColor: .clear
            ),
            nativeRoot: { ContentView() }
        )
    }
}
