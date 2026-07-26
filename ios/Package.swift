// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "XingGuangKit",
    defaultLocalization: "zh-Hans",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(name: "XingGuangKit", targets: ["XingGuangKit"]),
        .library(name: "XingGuangJavaScript", targets: ["XingGuangJavaScript"])
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.29.3")
    ],
    targets: [
        .target(
            name: "CQuickJS",
            path: "Sources/CQuickJS",
            exclude: ["quickjs/LICENSE", "quickjs/UPSTREAM_COMMIT.txt"],
            publicHeadersPath: "include",
            cSettings: [
                .define("CONFIG_VERSION", to: "\"2026-06-04\"")
            ]
        ),
        .target(
            name: "CGzip",
            path: "Sources/CGzip",
            publicHeadersPath: "include",
            linkerSettings: [.linkedLibrary("z")]
        ),
        .target(
            name: "XingGuangKit",
            dependencies: [
                "CGzip",
                .product(name: "GRDB", package: "GRDB.swift")
            ],
            resources: [.process("Resources")],
            linkerSettings: [.linkedFramework("MediaPlayer")]
        ),
        .target(
            name: "XingGuangJavaScript",
            dependencies: ["CQuickJS", "XingGuangKit"],
            resources: [.process("Resources")]
        )
    ]
)
