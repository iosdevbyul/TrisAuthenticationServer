// swift-tools-version:6.3
import PackageDescription

let package = Package(
    name: "AuthenticationServerKit",
    platforms: [.macOS(.v13)],
    products: [.library(name: "AuthenticationServerKit", targets: ["AuthenticationServerKit"])],
    targets: [
        .target(name: "AuthenticationServerKit"),
        .testTarget(name: "AuthenticationServerKitTests", dependencies: ["AuthenticationServerKit"]),
    ]
)
