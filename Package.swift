// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "StickyPagerKit",
    platforms: [.iOS(.v15)],
    products: [.library(name: "StickyPagerKit", targets: ["StickyPagerKit"])],
    dependencies: [
        // 仅提供格式化命令，不链接到框架或 Demo 的运行时产品。
        .package(url: "https://github.com/nicklockwood/SwiftFormat", exact: "0.64.0")
    ],
    targets: [
        .target(name: "StickyPagerKit"),
        .testTarget(name: "StickyPagerKitTests", dependencies: ["StickyPagerKit"])
    ],
    swiftLanguageModes: [.v6]
)
