import XCTest
@testable import BadasseoCore

final class AccessibilityNoticeTests: XCTestCase {
    func testTrustedIsPasteActiveForEveryChoice() {
        for choice in HotkeyChoice.options(appStore: false) {
            XCTAssertEqual(AccessibilityNotice(trusted: true, choice: choice), .pasteActive, "\(choice)")
        }
    }

    func testUntrustedHoldKeyBlocksHotkeyInOtherApps() {
        // 홀드 키는 전역 모니터가 필요 — 권한이 없으면 받아써 창이 앞에 있을 때만 감지된다
        for key in HoldKey.allCases {
            XCTAssertEqual(AccessibilityNotice(trusted: false, choice: .hold(key)), .hotkeyBlocked, "\(key)")
        }
    }

    func testUntrustedComboIsClipboardOnly() {
        // 조합 키(Carbon 핫키)는 권한 없이도 감지 — 자동 입력만 안 되고 클립보드에 담긴다
        XCTAssertEqual(AccessibilityNotice(trusted: false, choice: .combo), .clipboardOnly)
    }
}
