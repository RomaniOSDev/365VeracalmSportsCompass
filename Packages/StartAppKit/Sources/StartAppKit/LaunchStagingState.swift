import Combine
import Foundation

@MainActor
final class LaunchStagingState: ObservableObject {
    @Published var progress: Double = 0
    @Published var statusMessage: String

    init(statusMessage: String) {
        self.statusMessage = statusMessage
    }
}
