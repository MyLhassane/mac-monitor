// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "MacMonitorApp",
    platforms: [.macOS(.v10_15)],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.7.0"),
    ],
    targets: [
        .executableTarget(
            name: "MacMonitorApp",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
            ]
        ),
    ]
)
