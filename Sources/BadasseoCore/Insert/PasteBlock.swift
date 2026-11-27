import Foundation

/// 받아쓴 결과를 ⌘V로 자동 입력하지 못하는 이유. 이유마다 사용자가 할 일이 달라서 나눈다.
public enum PasteBlock: Equatable, Sendable {
    /// 손쉬운 사용 권한이 없다 — 사용자가 설정에서 켜야 한다.
    case noAccessibility
    /// 보안 입력 모드(암호 칸 입력용)가 켜져 있고, 맨 앞 앱이 켰거나 지금 칸이 암호 칸이거나 누가
    /// 켰는지 모른다. 권한과 무관하다.
    case secureInput

    /// 막는 것이 없으면 nil. 권한이 없으면 보안 입력과 관계없이 ⌘V를 보낼 수 없으므로 권한이 먼저다.
    ///
    /// 보안 입력은 시스템 전체에 걸려서, 켠 앱이 뒤에 있어도 켜진 것으로 읽힌다(2026-11-27 실사용:
    /// 뒤에 있던 Chrome 원격 데스크톱 때문에 모든 앱에서 붙여넣기가 멈췄다). 그 상태에서도 맨 앞
    /// 앱에 보낸 ⌘V는 들어가므로(같은 날 실험), 켠 앱이 뒤에 있다고 확인되고(`heldInBackground`)
    /// 지금 칸이 암호 칸이 아니면(`passwordFieldFocused`) 넣는다.
    public init?(trusted: Bool, secureInputOn: Bool, heldInBackground: Bool, passwordFieldFocused: Bool) {
        if !trusted {
            self = .noAccessibility
        } else if secureInputOn && !(heldInBackground && !passwordFieldFocused) {
            self = .secureInput
        } else {
            return nil
        }
    }
}
