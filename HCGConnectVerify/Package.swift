// swift-tools-version:5.7
// HCG Connect token verification for HCG Nexus (Nexus-owned, not vendored).
//
// The standalone app compiles Sources/HCGConnectVerify directly into its target
// (scripts/generate_xcodeproj.py); this package exists so the verifier and its
// rejection tests also build and run with `swift test` on Linux in CI.
// Apple platforms use CryptoKit; swift-crypto is used solely on Linux, exactly
// like the vendored HCGDeviceLink package.
import PackageDescription

var dependencies: [Package.Dependency] = []
var cryptoDependency: [Target.Dependency] = []
#if os(Linux)
dependencies.append(.package(url: "https://github.com/apple/swift-crypto.git", "3.0.0" ..< "4.0.0"))
cryptoDependency.append(.product(name: "Crypto", package: "swift-crypto"))
#endif

let package = Package(
    name: "HCGConnectVerify",
    platforms: [.iOS(.v14), .macOS(.v11)],
    products: [
        .library(name: "HCGConnectVerify", targets: ["HCGConnectVerify"]),
    ],
    dependencies: dependencies,
    targets: [
        .target(name: "HCGConnectVerify", dependencies: cryptoDependency),
        .testTarget(name: "HCGConnectVerifyTests", dependencies: ["HCGConnectVerify"] + cryptoDependency),
    ]
)
