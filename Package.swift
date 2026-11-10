// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "swift-llmstxt-org-llms-txt",
    platforms: [
        .macOS(.v27),
        .iOS(.v27),
        .tvOS(.v27),
        .watchOS(.v27),
        .visionOS(.v27),
    ],
    products: [
        .library(name: "LLMs Txt", targets: ["LLMs Txt"])
    ],
    dependencies: [
        .package(url: "https://github.com/swift-atoms/swift-ascii.git", branch: "main"),
        .package(url: "https://github.com/swift-ietf/swift-rfc-3986.git", branch: "main"),
        .package(url: "https://github.com/swift-molecules/swift-builder.git", branch: "main"),
        .package(url: "https://github.com/swift-molecules/swift-buffer-linear.git", branch: "main"),
        .package(
            url: "https://github.com/swift-molecules/swift-memory-allocation.git",
            branch: "main",
            traits: ["MemorySmall"]
        ),
        .package(url: "https://github.com/swift-atoms/swift-storage.git", branch: "main", traits: ["Memory"]),
    ],
    targets: [
        .target(
            name: "LLMs Txt",
            dependencies: [
                .product(name: "ASCII", package: "swift-ascii"),
                .product(name: "RFC 3986", package: "swift-rfc-3986"),
                .product(name: "Builder", package: "swift-builder"),
                .product(name: "Buffer Linear", package: "swift-buffer-linear"),
                .product(name: "Memory Allocator", package: "swift-memory-allocation"),
                .product(name: "Memory Small", package: "swift-memory-allocation"),
                .product(name: "Storage", package: "swift-storage"),
            ]
        ),
        .testTarget(
            name: "LLMs Txt Tests",
            dependencies: [
                .target(name: "LLMs Txt"),
                .product(name: "RFC 3986", package: "swift-rfc-3986"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    target.swiftSettings =
        (target.swiftSettings ?? []) + [
            .strictMemorySafety(),
            .enableUpcomingFeature("ExistentialAny"),
            .enableUpcomingFeature("InternalImportsByDefault"),
            .enableUpcomingFeature("MemberImportVisibility"),
            .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
            .enableUpcomingFeature("InferIsolatedConformances"),
            .enableExperimentalFeature("Lifetimes"),
            .treatAllWarnings(as: .error),
        ]
}
