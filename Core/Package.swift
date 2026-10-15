// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SCYDECore",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "SCYDECore", targets: ["SCYDECore"]),
    ],
    targets: [
        .target(name: "SCYDECore"),
        .testTarget(name: "SCYDECoreTests", dependencies: ["SCYDECore"]),
    ]
)
