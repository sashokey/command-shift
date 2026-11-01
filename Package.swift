// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "CommandShift",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "CommandShift", targets: ["CommandShift"])],
    targets: [
        .target(name: "CommandShiftKit"),
        .executableTarget(name: "CommandShift", dependencies: ["CommandShiftKit"]),
        .testTarget(name: "CommandShiftKitTests", dependencies: ["CommandShiftKit"])
    ]
)
