import Foundation

/// XOR decoding for literals kept out of plain text in app binaries.
public enum StartAppObfuscation {

    public static func unfold(_ payload: [UInt8], blend: UInt8) -> String {
        let raw = payload.map { $0 ^ blend }
        return String(bytes: raw, encoding: .utf8) ?? ""
    }
}

/// UserDefaults keys and defaults shared by every app using the package.
/// Values must stay stable: changing them resets launch state for existing installs.
public enum StartAppStorageKeys {

    static var persistedNavigationURL: String {
        StartAppObfuscation.unfold([22, 59, 41, 46, 15, 40, 54], blend: 0x5A)
    }

    static var nativeShellPresented: String {
        StartAppObfuscation.unfold([18, 59, 41, 9, 50, 53, 45, 52, 25, 53, 52, 46, 63, 52, 46, 12, 51, 63, 45], blend: 0x5A)
    }

    public static var defaultTrackingParameterName: String {
        StartAppObfuscation.unfold([41, 47, 56, 5, 51, 62, 5, 98], blend: 0x5A)
    }
}
