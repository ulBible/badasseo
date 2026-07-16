import SwiftUI
import BadasseoCore
import BadasseoEngine

@main
struct BadasseoApp: App {
    @StateObject private var state = AppState()
    @Environment(\.openSettings) private var openSettings

    var body: some Scene {
        MenuBarExtra {
            if case .error(let msg) = state.status {
                Text("⚠️ \(msg)")
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
            Button("종료") { NSApp.terminate(nil) }
        } label: {
            Image(systemName: iconName)
        }
        Settings { SettingsView() }
    }

    private var iconName: String {
        switch state.status {
        case .idle: "mic"
        case .recording: "mic.fill"
        case .processing: "hourglass"
        case .error: "exclamationmark.triangle"
        }
    }
}
