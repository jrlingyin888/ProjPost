// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ProjPost",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "ProjPostCore", targets: ["ProjPostCore"]),
        .executable(name: "ProjPostApp", targets: ["ProjPostApp"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0"),
        .package(url: "https://github.com/tuist/XcodeProj.git", from: "8.27.0")
    ],
    targets: [
        .target(
            name: "ProjPostCore",
            dependencies: [
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "XcodeProj", package: "XcodeProj")
            ]
        ),
        .executableTarget(
            name: "ProjPostApp",
            dependencies: ["ProjPostCore"]
        ),
        .testTarget(
            name: "ProjPostCoreTests",
            dependencies: ["ProjPostCore"]
        )
    ]
)
