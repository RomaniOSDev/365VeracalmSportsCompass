import Foundation
import os

enum StartAppLogger {
    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "StartApp", category: "StartApp")

    static func debug(_ message: String) {
        #if DEBUG
        log.debug("\(message, privacy: .public)")
        #endif
    }

    static func notice(_ message: String) {
        #if DEBUG
        log.notice("\(message, privacy: .public)")
        #endif
    }
}
