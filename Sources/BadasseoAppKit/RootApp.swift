import SwiftUI
import AppKit
import BadasseoCore
import BadasseoEngine

/// GitHub / Mac App Store 빌드 변형 구분. 2.4.5 하드닝(vClips 손쉬운 사용 자동붙여넣기
/// 거부 대응)으로 MAS 변형은 권한이 필요 없는 경로를 기본으로 안내한다 —
/// HotkeyStep 프리셀렉트·카드 순서, About 패널 Support 링크 숨김 등에서 분기.
public enum BuildVariant {
    case github
    case appStore
}

extension BuildVariant {
    /// 실행 중인 번들이 Mac App Store 변형인지. Info-AppStore.plist가 app.badasseo.mas를 설정한다.
    static var current: BuildVariant { Bundle.main.bundleIdentifier == "app.badasseo.mas" ? .appStore : .github }
}

/// 앱 종료 시 whisper.cpp(Metal) 정적 소멸자 abort를 우회하는 델리게이트.
///
/// whisper.cpp가 한 번이라도 Metal을 초기화하면(=전사 1회 이상, 또는
/// WhisperEngine 생성만 해도) 전역 `ggml_metal_device` 레지스트리가 만들어진다.
/// 이 레지스트리는 우리가 제어하지 않는 C++ 정적 소멸자(`__cxa_finalize_ranges`,
/// 즉 libc `exit()` 경로)에서 해제되는데, 그 해제 로직 안의 GGML_ASSERT가
/// 정상 상태에서도 abort()를 던진다(whisper.cpp 자체 버그, 우리 쪽 whisper_free
/// 호출과 무관 — WhisperEngine.deinit은 별개로 정상 동작).
///
/// 표준 우회책은 libc의 exit()/atexit·정적 소멸자 경로를 완전히 건너뛰는
/// `_exit(0)`으로 프로세스를 끝내는 것. AppKit이 정상 종료 처리를 마친 뒤
/// (`applicationWillTerminate`) 이 방법을 쓴다.
///
/// _exit(0)이 안전한 이유: 이 앱의 영속 상태는 (1) UserDefaults
/// (onboardingDone, hotkeyMode, holdKey, soundFeedback) — 아래서 synchronize(),
/// (2) HistoryStore/UserDictionary의 JSON — 값이 바뀔 때마다 그 자리에서
/// 동기적으로 `Data.write(to:)`로 디스크에 쓰기 때문에 종료 시점에 대기 중인
/// 쓰기가 없음, (3) 진행 중이던 모델 다운로드 — 프로세스가 죽으면(정상 exit이든
/// _exit이든 동일) 처음부터 다시 받게 되지만 재실행 시 자동 진행되므로 허용 가능.
/// 즉 _exit(0)이 추가로 잃는 것은 없다(정상 종료도 같은 손실).
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillTerminate(_ notification: Notification) {
        UserDefaults.standard.synchronize()
        _exit(0)
    }
}

/// GitHub 빌드(Badasseo 타깃)의 main.swift가 `BadasseoRootApp.main()` 호출 전에
/// Sparkle 업데이트 훅을 여기 주입한다. Mac App Store 빌드(BadasseoAppStore)는
/// Sparkle을 링크하지 않으므로(Package.swift 참고) 이 값을 nil로 남겨 메뉴 항목이
/// 숨겨진다 — vClips의 `checkForUpdates: (() -> Void)?` 파라미터와 같은 역할이지만,
/// BadasseoRootApp은 두 타깃이 공유하는 `App`을 `static main()`으로 실행하므로
/// (init 파라미터를 넘길 방법이 없음) 생성자 대신 전역 변수로 주입한다.
/// main.swift 최상위 코드는 Swift 6에서 MainActor로 추론되고 읽기도 body(MainActor)
/// 뿐이라, @MainActor 격리로 컴파일러가 안전성을 정적으로 보장한다.
@MainActor public var badasseoCheckForUpdates: (() -> Void)?

/// 두 실행 타깃(Badasseo/BadasseoAppStore)의 공용 앱 진입점. 각 타깃의 얇은
/// main.swift가 `BadasseoRootApp.main()`을 호출한다(SwiftUI `App` 프로토콜의
/// 기본 구현이 static main()을 제공).
public struct BadasseoRootApp: App {
    public init() {
        // ggml Metal residency sets를 끈다 — 이 서브시스템이 두 가지 실사고의 근원:
        // ① 종료 시 정적 소멸자 abort(ggml_metal_rsets_free → _exit 우회 중)
        // ② 로드 중 residency 거부 시 무한 재시도 루프가 시도마다 누수(실측 16GB, 전사 영구 멈춤).
        // 짧은 발화 전사에서 residency 최적화 이득은 무시 가능한 수준.
        setenv("GGML_METAL_NO_RESIDENCY", "1", 1)

        // 이미 온보딩을 완료한 기존 사용자는 OnboardingModel.finish()가 다시 실행되지
        // 않아 로그인 시 자동 실행 기본값을 못 받는다 — 1회 소급 적용(설정 > 시작에서
        // 언제든 해제 가능). 실패(미설치 빌드)는 조용히 무시.
        // GitHub 변형 전용: MAS 리뷰어는 항상 신규 설치라 온보딩 체크박스 동의
        // (OnboardingModel.enableLaunchAtLogin, TutorialStep)를 거침; 소급 등록은
        // 그 체크박스가 생기기 전부터 있었던 GitHub 기존 사용자 전용이다(2.4.5(iii)
        // 대응 — MAS 심사 경로에 무동의 자동 등록이 남지 않도록 belt and braces).
        let migratedKey = "launchAtLoginMigrated"
        if BuildVariant.current == .github, OnboardingModel.isDone, !UserDefaults.standard.bool(forKey: migratedKey) {
            try? LaunchAtLogin.set(enabled: true)
            UserDefaults.standard.set(true, forKey: migratedKey)
        }
    }

    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var state = AppState()
    @Environment(\.openWindow) private var openWindow

    public var body: some Scene {
        MenuBarExtra {
            if case .error(let msg) = state.status {
                Text("⚠️ \(msg)")
            }
            if case .noSpeech = state.status {
                Text("다시 말해주세요")
            }
            if !state.lastResult.isEmpty {
                Text("마지막: \(String(state.lastResult.prefix(30)))")
            }
            Divider()
            Text(TextInserter.hasAccessibility
                 ? "붙여넣기: 활성" : "손쉬운 사용 권한 필요 — 클립보드 복사만 동작")
            Button("설정…") {
                // 메뉴바 전용(LSUIElement) 앱은 비활성 상태라 설정 창이 뒤에 열림 —
                // 먼저 앱을 활성화해 창을 포그라운드로.
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "settings")
            }
            .keyboardShortcut(",", modifiers: .command)
            Button("온보딩 다시 보기") {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "onboarding")
            }
            if let checkForUpdates = badasseoCheckForUpdates {
                Button("업데이트 확인…") {
                    // 메뉴바 전용(LSUIElement) 앱은 비활성 상태라 업데이트 창이
                    // 뒤에 열림 — 설정/온보딩과 같은 이유로 먼저 앱을 활성화.
                    NSApp.activate(ignoringOtherApps: true)
                    checkForUpdates()
                }
            }
            Button("받아써 정보") {
                AboutPanel.show(showsSupportLink: BuildVariant.current == .github)
            }
            Divider()
            Button("종료") { NSApp.terminate(nil) }
        } label: {
            Group {
                switch state.status {
                case .idle where Self.menuBarMark != nil:
                    Image(nsImage: Self.menuBarMark!)
                case .processing where Self.processingFrames.count == 4:
                    // 변환 중: 텍스트 3줄이 타이핑되듯 차오르는 프레임 순환 (0→1→2→3줄).
                    // 프레임은 AppState의 타이머가 0.18s마다 진행 (라벨에 TimelineView 금지 —
                    // AppState.status didSet 주석 참고).
                    Image(nsImage: Self.processingFrames[state.processingFrame % 4])
                default:
                    Image(systemName: iconName)
                }
            }
            .onAppear {
                if !OnboardingModel.isDone {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "onboarding")
                }
            }
        }
        .commands {
            // MenuBarExtra 항목의 keyboardShortcut은 상태바 메뉴 안에서만 표시될 뿐
            // 전역 단축키로 라우팅되지 않음 — 예전 `Settings` scene이 암묵적으로
            // 앱 메뉴에 등록해 주던 전역 ⌘, 동작을 CommandGroup으로 대신 복원.
            CommandGroup(replacing: .appSettings) {
                Button("설정…") {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "settings")
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
        Window("받아써 시작하기", id: "onboarding") {
            OnboardingView()
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        Window("설정", id: "settings") {
            SettingsView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }

    private var iconName: String {
        switch state.status {
        case .idle: "mic"
        case .recording: "mic.fill"
        case .processing: "hourglass"
        case .noSpeech: "mic.slash"
        case .error: "exclamationmark.triangle"
        }
    }

    /// 번들 PNG(1x/2x)를 한 NSImage로 합쳐 템플릿(라이트/다크 자동 틴트)으로 로드.
    static func templateImage(_ base: String) -> NSImage? {
        let img = NSImage(size: NSSize(width: 22, height: 18))
        var loaded = false
        for name in [base, base + "@2x"] {
            guard let url = Bundle.module.url(forResource: name, withExtension: "png"),
                  let rep = NSBitmapImageRep(data: (try? Data(contentsOf: url)) ?? Data())
            else { continue }
            rep.size = NSSize(width: 22, height: 18)
            img.addRepresentation(rep)
            loaded = true
        }
        guard loaded else { return nil }
        img.isTemplate = true
        return img
    }

    /// 평상시(idle) 메뉴바 아이콘 — 앱 아이콘과 같은 심볼(마이크+3줄)의 템플릿판.
    /// 녹음·오류 등 상태 표시는 의미 전달이 우선이라 SF Symbols를 유지한다.
    static let menuBarMark: NSImage? = templateImage("menubar-icon")

    /// 변환 중 타이핑 애니메이션 프레임(0~3줄). 4장이 모두 있어야 사용한다.
    static let processingFrames: [NSImage] = (0...3).compactMap { templateImage("menubar-frame\($0)") }
}
