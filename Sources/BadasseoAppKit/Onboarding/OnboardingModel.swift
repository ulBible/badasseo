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
    ///
    /// macOS 14+에서는 TCC 다이얼로그가 닫히며 포커스를 되돌리는 시점이 우리 activate
    /// 호출 뒤에 오는 경쟁이 있어(협조적 활성화), 1회 호출로는 창이 다시 뒤로 밀릴 수
    /// 있다. 즉시 1회 + 지연 2회(총 3회) 재시도하고, 매번 `orderFrontRegardless()`도
    /// 함께 호출해 활성화 자체가 거부되는 경우에도 창만은 앞으로 오게 한다.
    static func bringToFront() {
        func attempt() {
            NSApp.activate(ignoringOtherApps: true)
            if let w = NSApp.windows.first(where: { $0.identifier?.rawValue == "onboarding" })
                ?? NSApp.windows.first(where: { $0.title == "받아써 시작하기" }) {
                w.makeKeyAndOrderFront(nil)
                w.orderFrontRegardless()   // 활성화가 거부돼도 창은 앞으로
            }
        }
        attempt()
        // TCC 다이얼로그 해제가 우리 호출 뒤에 포커스를 되돌리는 경쟁 — 늦게 두 번 더.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { attempt() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { attempt() }
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
