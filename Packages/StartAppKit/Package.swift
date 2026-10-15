// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "StartAppKit",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(name: "StartAppKit", targets: ["StartAppKit"])
    ],
    targets: [
        .target(name: "StartAppKit")
    ]
)
