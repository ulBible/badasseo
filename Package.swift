// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Badasseo",
    platforms: [.macOS(.v14)],
    products: [
        // GitHub-release variant.
        .executable(name: "Badasseo", targets: ["Badasseo"]),
        // Mac App Store (sandboxed) variant — see Resources/Badasseo-AppStore.entitlements.
        .executable(name: "BadasseoAppStore", targets: ["BadasseoAppStore"]),
        .executable(name: "badasseo-cli", targets: ["badasseo-cli"]),
    ],
    dependencies: [
        // whisper.cpp removed its Package.swift from the repo root in March 2025
        // (commit 5bb1d58c, "whisper: add xcframework build script") in favor of
        // publishing a prebuilt XCFramework per release. The README-documented
        // SPM fallback `ggml-org/whisper.spm` 301-redirects to a stale
        // ggerganov/whisper.spm repo (last pushed 2024-05-27) whose manifest
        // explicitly EXCLUDES ggml-metal.m/.metal ("TODO: make Metal work, I
        // can't figure out how") and predates whisper.cpp's current ggml
        // backend layout. Using it would silently ship a CPU-only, out-of-date
        // engine. Instead we consume the official prebuilt XCFramework
        // (see the `whisper` binaryTarget below), which is the path documented
        // in whisper.cpp's current README ("## XCFramework" section) and is
        // confirmed to link Metal.framework and contain compiled Metal
        // backend symbols.
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0"),
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.0"),
    ],
    targets: [
        .target(name: "BadasseoCore", path: "Sources/BadasseoCore"),
        .binaryTarget(
            name: "whisper",
            url: "https://github.com/ggml-org/whisper.cpp/releases/download/v1.9.1/whisper-v1.9.1-xcframework.zip",
            checksum: "8c3ecbe73f48b0cb9318fc3058264f951ab336fd530e82c4ccdd2298d1311a4c"
        ),
        .target(
            name: "BadasseoEngine",
            dependencies: [
                "BadasseoCore",
                "whisper",
            ],
            path: "Sources/BadasseoEngine"
        ),
        .target(
            name: "BadasseoAppKit",
            dependencies: [
                "BadasseoCore", "BadasseoEngine",
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
            ],
            path: "Sources/BadasseoAppKit",
            resources: [.process("Resources")]   // 사운드 wav 이동 포함
        ),
        // GitHub-release variant: links Sparkle for auto-updates. The App
        // Store variant below intentionally does not — the store owns
        // updates there, and BadasseoAppKit stays shared by both so the
        // updater hook is injected via a var in RootApp.swift instead.
        .executableTarget(
            name: "Badasseo",
            dependencies: [
                "BadasseoAppKit",
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Sources/Badasseo"
        ),
        .executableTarget(name: "BadasseoAppStore", dependencies: ["BadasseoAppKit"], path: "Sources/BadasseoAppStore"),
        .executableTarget(
            name: "badasseo-cli",
            dependencies: ["BadasseoCore", "BadasseoEngine"],
            path: "Sources/badasseo-cli"
        ),
        .testTarget(
            name: "BadasseoCoreTests",
            dependencies: ["BadasseoCore"],
            path: "Tests/BadasseoCoreTests"
        ),
    ]
)
