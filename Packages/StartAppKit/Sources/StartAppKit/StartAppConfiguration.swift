import SwiftUI
import UIKit

/// App-provided settings for the start app flow.
public struct StartAppConfiguration {

    /// Gate day in `dd.MM.yyyy`. Web/staging is allowed from this calendar day on.
    public var calendarGateAnchor: String

    /// Base remote entry URL. Tracking query item is appended at runtime. Defaults to Google.
    public var remoteEntryTemplate: String

    public var trackingParameterName: String
    public var gateTimeZone: TimeZone

    public var stagingMessage: String
    public var stagingBackground: Image?
    public var stagingStyle: StartAppStagingStyle

    public var makeNativeRoot: @MainActor () -> UIViewController

    /// Used when the app does not provide its own entry URL.
    public static let defaultRemoteEntryTemplate = "https://www.google.com"

    public init(
        calendarGateAnchor: String,
        remoteEntryTemplate: String = StartAppConfiguration.defaultRemoteEntryTemplate,
        trackingParameterName: String = StartAppStorageKeys.defaultTrackingParameterName,
        gateTimeZone: TimeZone = .current,
        stagingMessage: String = "Loading...",
        stagingBackground: Image? = nil,
        stagingStyle: StartAppStagingStyle = .default,
        makeNativeRoot: @escaping @MainActor () -> UIViewController
    ) {
        self.calendarGateAnchor = calendarGateAnchor
        self.remoteEntryTemplate = remoteEntryTemplate
        self.trackingParameterName = trackingParameterName
        self.gateTimeZone = gateTimeZone
        self.stagingMessage = stagingMessage
        self.stagingBackground = stagingBackground
        self.stagingStyle = stagingStyle
        self.makeNativeRoot = makeNativeRoot
    }

    public init<NativeRoot: View>(
        calendarGateAnchor: String,
        remoteEntryTemplate: String = StartAppConfiguration.defaultRemoteEntryTemplate,
        trackingParameterName: String = StartAppStorageKeys.defaultTrackingParameterName,
        gateTimeZone: TimeZone = .current,
        stagingMessage: String = "Loading...",
        stagingBackground: Image? = nil,
        stagingStyle: StartAppStagingStyle = .default,
        nativeRoot: @escaping @MainActor () -> NativeRoot
    ) {
        self.init(
            calendarGateAnchor: calendarGateAnchor,
            remoteEntryTemplate: remoteEntryTemplate,
            trackingParameterName: trackingParameterName,
            gateTimeZone: gateTimeZone,
            stagingMessage: stagingMessage,
            stagingBackground: stagingBackground,
            stagingStyle: stagingStyle,
            makeNativeRoot: { UIHostingController(rootView: nativeRoot()) }
        )
    }
}
