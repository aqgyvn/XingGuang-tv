// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "XingGuangKit",
    defaultLocalization: "zh-Hans",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(name: "XingGuangKit", targets: ["XingGuangKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.29.3")
    ],
    targets: [
        .target(
            name: "XingGuangKit",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift")
            ],
            resources: [.process("Resources")]
        )
    ]
)
