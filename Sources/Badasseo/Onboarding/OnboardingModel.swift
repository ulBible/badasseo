import SwiftUI
import BadasseoEngine

@MainActor
final class OnboardingModel: ObservableObject {
    static let doneKey = "onboardingDone"
    static var isDone: Bool { UserDefaults.standard.bool(forKey: doneKey) }

    @Published var step = 0            // 0환영 1다운로드 2마이크 3단축키·권한 4튜토리얼
    let modelStore = ModelStore()

    func next() { if step < 4 { step += 1 } else { finish() } }
    func skip() { finish() }
    func finish() {
        UserDefaults.standard.set(true, forKey: Self.doneKey)
        NSApp.keyWindow?.close()
    }
}
