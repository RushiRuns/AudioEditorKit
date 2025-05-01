// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AudioEditorKit",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v16),
        .macCatalyst(.v16),
        .visionOS(.v1),
    ],
    products: [
        .library(name: "AudioEditorKit", targets: ["AudioEditorKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-atomics.git", from: "1.2.0"),
        .package(url: "https://github.com/relatedcode/ProgressHUD.git", from: "14.1.3"),
    ],
    targets: [
        .target(name: "AudioEditorKit", dependencies: [
            "AudioClip",
            "AudioClipView",
            "AudioClipEditor",
            "WaveformAnalyzer",
        ]),
        .target(name: "AudioClipEditor", dependencies: [
            "AudioClipView",
            "AudioClipPlayer",
            "ProgressHUD",
        ], resources: [
            .process("Resources/AudioClipController.storyboard"),
            .process("Resources/AudioClipController_iPad.storyboard"),
        ]),
        .target(name: "AudioClipView", dependencies: [
            "AudioClip",
            "AudioClipPlayer",
            .product(name: "Atomics", package: "swift-atomics"),
        ], resources: [
            .process("Resources/Colors.xcassets"),
        ]),
        .target(name: "AudioClip", dependencies: [
            "WaveformAnalyzer",
        ]),
        .target(name: "AudioClipPlayer"),
        .target(name: "WaveformAnalyzer", dependencies: [
            .product(name: "Atomics", package: "swift-atomics"),
        ]),
    ]
)
