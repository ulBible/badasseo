// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Badasseo",
    // Source language = Korean. English is the one bundled translation (see
    // Sources/BadasseoAppKit/Resources/Localizable.xcstrings); unsupported
    // languages fall back to Korean.
    defaultLocalization: "ko",
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
        // whisper.cpp v1.9.5 (commit d1be6fd). Since v1.9.3 upstream attaches no
        // binaries to the vX.Y.Z release; the xcframework is published on the
        // build-number release of the same commit (v1.9.5 == b5454, where b<N>
        // is `git rev-list --count`). Those releases are flagged pre-release
        // with no stated retention policy: the checksum pins the bytes, so the
        // only risk is the URL going away.
        // To bump: confirm `git ls-remote --tags` shows vX.Y.Z^{} and b<N> on
        // the same commit, then copy that asset's sha256. These builds report
        // whisper_version() as "X.Y.Z-dev".
        .binaryTarget(
            name: "whisper",
            url: "https://github.com/ggml-org/whisper.cpp/releases/download/b5454/whisper-b5454-xcframework.zip",
            checksum: "e57f8c48933000acabc13bb913fbe82805d483a2deff692cc6738836bd92393b"
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
