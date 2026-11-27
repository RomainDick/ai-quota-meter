// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AIQuotaMeter",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "AIQuotaMeter", path: "Sources/AIQuotaMeter")
    ]
)
