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

/// 두 실행 타깃(Badasseo/BadasseoAppStore)의 공용 앱 진입점. 각 타깃의 얇은
/// main.swift가 `BadasseoRootApp.main()`을 호출한다(SwiftUI `App` 프로토콜의
/// 기본 구현이 static main()을 제공).
public struct BadasseoRootApp: App {
    public init() {}

    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var state = AppState()
    @Environment(\.openSettings) private var openSettings
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
                openSettings()
            }
            Button("온보딩 다시 보기") {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "onboarding")
            }
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
        Window("받아써 시작하기", id: "onboarding") {
            OnboardingView()
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        Settings { SettingsView() }
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
