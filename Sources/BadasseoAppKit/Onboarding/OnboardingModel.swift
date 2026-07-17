import SwiftUI
import BadasseoEngine

@MainActor
final class OnboardingModel: ObservableObject {
    static let doneKey = "onboardingDone"
    static var isDone: Bool { UserDefaults.standard.bool(forKey: doneKey) }

    /// 앱 레벨 공유 — 온보딩 창을 닫았다 다시 열어도 같은 인스턴스를 써서 이중 1.6GB 다운로드를 막는다.
    static let sharedModelStore = ModelStore()

    @Published var step = 0            // 0환영 1다운로드 2마이크 3단축키·권한 4튜토리얼
    let modelStore = OnboardingModel.sharedModelStore

    func next() { if step < 4 { step += 1 } else { finish() } }
    func skip() { finish() }

    /// 권한 대화상자 응답 등으로 뒤로 밀린 온보딩 창을 다시 앞으로 (LSUIElement 앱).
    static func bringToFront() {
        NSApp.activate(ignoringOtherApps: true)
        let win = NSApp.windows.first { $0.identifier?.rawValue == "onboarding" }
            ?? NSApp.windows.first { $0.title == "받아써 시작하기" }
        win?.makeKeyAndOrderFront(nil)
    }
    func finish() {
        UserDefaults.standard.set(true, forKey: Self.doneKey)
        if let onboarding = NSApp.windows.first(where: { $0.identifier?.rawValue == "onboarding" }) {
            onboarding.close()
        } else {
            NSApp.windows.first { $0.title == "받아써 시작하기" }?.close()
        }
    }
}
