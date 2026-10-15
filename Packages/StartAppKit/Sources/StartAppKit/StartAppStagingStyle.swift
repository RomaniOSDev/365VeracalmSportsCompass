import SwiftUI

/// Colors of the staging (loading) screen. Every value has a default, so pass only what you want to change.
public struct StartAppStagingStyle {

    /// Fill behind the optional background image.
    public var backgroundColor: Color
    /// Top-to-bottom gradient drawn over the background image to keep text readable.
    public var overlayColors: [Color]
    /// Filled part of the progress bar.
    public var progressTint: Color
    /// Unfilled part of the progress bar.
    public var progressTrackColor: Color
    /// Status message color.
    public var textColor: Color
    /// Status message shadow; use `.clear` to disable.
    public var textShadowColor: Color

    public init(
        backgroundColor: Color = .black,
        overlayColors: [Color] = [Color.black.opacity(0.35), Color.black.opacity(0.6)],
        progressTint: Color = .white,
        progressTrackColor: Color = Color.white.opacity(0.25),
        textColor: Color = .white,
        textShadowColor: Color = Color.black.opacity(0.5)
    ) {
        self.backgroundColor = backgroundColor
        self.overlayColors = overlayColors
        self.progressTint = progressTint
        self.progressTrackColor = progressTrackColor
        self.textColor = textColor
        self.textShadowColor = textShadowColor
    }

    public static let `default` = StartAppStagingStyle()
}
