import Foundation

#if DEBUG
public enum StartAppDebugOverride: String, CaseIterable {
    case automatic
    case forceNative
    case forceWeb
    case forceStaging
}

public enum StartAppDebugOptions {
    private static let overrideKey = "start_app_debug_override"

    public static var current: StartAppDebugOverride {
        guard let raw = UserDefaults.standard.string(forKey: overrideKey),
              let value = StartAppDebugOverride(rawValue: raw) else {
            return .automatic
        }
        return value
    }

    public static func set(_ override: StartAppDebugOverride) {
        UserDefaults.standard.set(override.rawValue, forKey: overrideKey)
    }
}
#endif
