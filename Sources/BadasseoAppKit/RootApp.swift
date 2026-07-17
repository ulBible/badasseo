import SwiftUI
import BadasseoCore
import BadasseoEngine

/// GitHub / Mac App Store 빌드 변형 구분. 현재는 두 변형 동일 동작(분기 내용 없음) —
/// vClips 재심사 결과가 나오면 카피·프리셀렉트 분기를 여기 채운다.
public enum BuildVariant {
    case github
    case appStore
}

/// 두 실행 타깃(Badasseo/BadasseoAppStore)의 공용 앱 진입점. 각 타깃의 얇은
/// main.swift가 `BadasseoRootApp.main()`을 호출한다(SwiftUI `App` 프로토콜의
/// 기본 구현이 static main()을 제공).
public struct BadasseoRootApp: App {
    public init() {}

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
