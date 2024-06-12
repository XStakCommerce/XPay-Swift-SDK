// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "XPayPaymentKit",
    platforms: [
        .iOS(.v15),
        .macOS(.v10_15)
    ],
    products: [
        .library(
            name: "XPayPaymentKit",
            targets: ["XPayPaymentKit"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "XPayPaymentKit",
            dependencies: [],
            path: "Sources/XPayPaymentKit"
        ),
        .testTarget(
            name: "XPayPaymentKitTests",
            dependencies: ["XPayPaymentKit"]),
    ]
)
