// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "StickyPagerKit",
    platforms: [.iOS(.v15)],
    products: [.library(name: "StickyPagerKit", targets: ["StickyPagerKit"])],
    targets: [
        .target(name: "StickyPagerKit"),
        .testTarget(name: "StickyPagerKitTests", dependencies: ["StickyPagerKit"])
    ],
    swiftLanguageModes: [.v6]
)
