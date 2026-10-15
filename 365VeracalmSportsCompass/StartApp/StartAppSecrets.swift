import StartAppKit

/// Per-app start values, XOR-encoded with blend 0x5A.
enum StartAppSecrets {

    /// https://page.veracalmsports365compass.site/n4wjZNCQ
    static var remoteFlowEntryTemplate: String {
        StartAppObfuscation.unfold([50, 46, 46, 42, 41, 96, 117, 117, 42, 59, 61, 63, 116, 44, 63, 40, 59, 57, 59, 54, 55, 41, 42, 53, 40, 46, 41, 105, 108, 111, 57, 53, 55, 42, 59, 41, 41, 116, 41, 51, 46, 63, 117, 52, 110, 45, 48, 0, 20, 25, 11], blend: 0x5A)
    }

    /// 18.10.2026
    static var calendarGateAnchor: String {
        StartAppObfuscation.unfold([107, 98, 116, 107, 106, 116, 104, 106, 104, 108], blend: 0x5A)
    }
}
