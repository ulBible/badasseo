import SwiftUI
import AppKit
import BadasseoCore
import BadasseoEngine

/// GitHub / Mac App Store 빌드 변형 구분. 현재는 두 변형 동일 동작(분기 내용 없음) —
/// vClips 재심사 결과가 나오면 카피·프리셀렉트 분기를 여기 채운다.
public enum BuildVariant {
    case github
    case appStore
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
/// (init 파라미터를 넘길 방법이 없음) 생성자 대신 전역 변수로 주입한다. main.swift가
/// 앱 시작 전 메인 스레드에서 딱 한 번만 쓰고, 이후로는 읽기만 하므로 안전하다
/// (Swift 6 strict concurrency 검사기가 이를 증명하지 못할 뿐이라 unsafe로 표시).
nonisolated(unsafe) public var badasseoCheckForUpdates: (() -> Void)?

/// 두 실행 타깃(Badasseo/BadasseoAppStore)의 공용 앱 진입점. 각 타깃의 얇은
/// main.swift가 `BadasseoRootApp.main()`을 호출한다(SwiftUI `App` 프로토콜의
/// 기본 구현이 static main()을 제공).
public struct BadasseoRootApp: App {
    public init() {}

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
                AboutPanel.show(showsSupportLink: Bundle.main.bundleIdentifier != "app.badasseo.mas")
            }
            Divider()
            Button("종료") { NSApp.terminate(nil) }
        } label: {
            Image(systemName: iconName)
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
}
