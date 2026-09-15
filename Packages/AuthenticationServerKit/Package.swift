// swift-tools-version:6.3
import PackageDescription

let package = Package(
    name: "AuthenticationServerKit",
    platforms: [.macOS(.v13)],
    products: [.library(name: "AuthenticationServerKit", targets: ["AuthenticationServerKit"])],
    dependencies: [
        .package(url: "https://github.com/vapor/jwt.git", from: "5.0.0"),
        // Match the host's existing compiler compatibility constraint.
        .package(url: "https://github.com/vapor/jwt-kit.git", exact: "5.6.0"),
        .package(url: "https://github.com/vapor/vapor.git", from: "4.121.4"),
        .package(url: "https://github.com/vapor/fluent.git", from: "4.9.0"),
        .package(url: "https://github.com/vapor/sql-kit.git", from: "3.36.0"),
    ],
    targets: [
        .target(name: "AuthenticationServerKit", dependencies: [
            .product(name: "JWT", package: "jwt"),
            .product(name: "JWTKit", package: "jwt-kit"),
            .product(name: "Vapor", package: "vapor"),
            .product(name: "Fluent", package: "fluent"),
            .product(name: "SQLKit", package: "sql-kit"),
        ]),
        .testTarget(name: "AuthenticationServerKitTests", dependencies: [.target(name: "AuthenticationServerKit"), .product(name: "VaporTesting", package: "vapor")]),
    ]
)
