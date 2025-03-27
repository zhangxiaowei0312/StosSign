// swift-tools-version: 5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "StosSign",
    platforms: [
        .iOS(.v14),
        .macOS(.v11),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "StosSign",
            // type: .dynamic,
            targets: ["StosSign", "CCoreCrypto", "CoreCrypto", "StosOpenSSL"]),
    ],
    dependencies: [
        // .package(url: "https://github.com/krzyzanowskim/OpenSSL.git", from: "3.3.2000"),
        .package(url: "https://github.com/zwsn/zsign-ios.git", branch: "main")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "CCoreCrypto",
            path: "Sources/Dependencies/corecrypto",
            exclude: [
                "Sources/CoreCryptoMacros.swift"
            ],
            cSettings: [
                .headerSearchPath("include/corecrypto"),
                .define("CORECRYPTO_DONOT_USE_TRANSPARENT_UNION=1")
            ]
        ),

        .target(
            name: "CoreCrypto",
            dependencies: ["CCoreCrypto"],
            path: "Sources/Dependencies/corecrypto/Sources",
            exclude: [
                "ccsrp.m"
            ],
            sources: [
                "CoreCryptoMacros.swift"
            ],
            cSettings: [
                .define("CORECRYPTO_DONOT_USE_TRANSPARENT_UNION=1")
            ]
        ),
        .target(
            name: "StosSign",
            dependencies: [
                .product(name: "ZSignApple", package: "zsign-ios"),
                "CoreCrypto",
                "StosOpenSSL"
            ],
            exclude: [
                "Sources/Dependencies",
            ]
        ),
        .target(
            name: "StosOpenSSL",
            dependencies: [
                .product(name: "ZSignApple", package: "zsign-ios")
            ],
            path: "Sources/Dependencies/Modules/OpenSSL"
        ),
    ],
    
    cLanguageStandard: CLanguageStandard.gnu11,
    cxxLanguageStandard: .cxx14
)
