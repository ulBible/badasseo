import Foundation

/// 메뉴바 메뉴에 보여 줄 손쉬운 사용 상태 안내 — 권한과 녹음 키 선택에 따라 뜻이 달라진다.
public enum AccessibilityNotice: Equatable {
    /// 권한 있음 — 다른 앱에서 단축키 감지·자동 입력 모두 동작.
    case pasteActive
    /// 권한 없음 + 홀드 키 — 전역 감지가 없어 받아써 창이 앞에 있을 때만 단축키가 먹는다.
    case hotkeyBlocked
    /// 권한 없음 + 조합 키 — 단축키(Carbon)는 동작하지만 결과는 클립보드에만 담긴다.
    case clipboardOnly

    public init(trusted: Bool, choice: HotkeyChoice) {
        if trusted {
            self = .pasteActive
        } else {
            self = choice.requiresAccessibility ? .hotkeyBlocked : .clipboardOnly
        }
    }
}
