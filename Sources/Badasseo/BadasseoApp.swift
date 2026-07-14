import SwiftUI
import BadasseoCore
import BadasseoEngine

@main
struct BadasseoApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        MenuBarExtra {
            if case .error(let msg) = state.status {
                Text("⚠️ \(msg)")
            }
            if !state.lastResult.isEmpty {
                Text("마지막: \(String(state.lastResult.prefix(30)))")
            }
            Divider()
            ForEach(Array(state.recent.prefix(5).enumerated()), id: \.offset) { _, e in
                Button(String(e.text.prefix(40))) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(e.text, forType: .string)
                }
            }
            Divider()
            Text(TextInserter.hasAccessibility
                 ? "붙여넣기: 활성" : "손쉬운 사용 권한 필요 — 클립보드 복사만 동작")
            Button("종료") { NSApp.terminate(nil) }
        } label: {
            Image(systemName: iconName)
        }
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
