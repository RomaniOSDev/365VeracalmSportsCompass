import Foundation

/// Start app persistence (`LastUrl`, native shell flag).
final class LaunchSessionStore {
    static let shared = LaunchSessionStore()

    private let defaults = UserDefaults.standard
    private var lastURLKey: String { StartAppStorageKeys.persistedNavigationURL }
    private var nativeShellKey: String { StartAppStorageKeys.nativeShellPresented }

    /// Persisted document URL after first successful WebView load (`LastUrl`).
    var savedLastURL: URL? {
        get {
            if let url = defaults.url(forKey: lastURLKey) {
                return url
            }
            if let legacy = defaults.string(forKey: lastURLKey),
               let url = URL(string: legacy) {
                defaults.set(url, forKey: lastURLKey)
                return url
            }
            return nil
        }
        set {
            defaults.set(newValue, forKey: lastURLKey)
        }
    }

    var hasShownNativeShell: Bool {
        get { defaults.bool(forKey: nativeShellKey) }
        set { defaults.set(newValue, forKey: nativeShellKey) }
    }

    private init() {}
}
