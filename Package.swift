// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "PetalCore",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [.library(name: "PetalCore", targets: ["PetalCore"])],
    targets: [
        .target(name: "PetalCore", path: "Petal/Core"),
        .testTarget(name: "PetalCoreTests", dependencies: ["PetalCore"], path: "PetalTests")
    ]
)
