// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Atajoly",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Atajoly",
            path: "Sources/Atajoly"
        )
    ]
)
