import XCTest
@testable import BadasseoCore

final class PasteBlockTests: XCTestCase {
    func testNothingBlocksWhenTrustedAndSecureInputOff() {
        XCTAssertNil(PasteBlock(trusted: true, secureInputOn: false,
                                heldInBackground: false, passwordFieldFocused: false))
    }

    func testBackgroundSecureInputDoesNotBlock() {
        // 2026-11-27 실사용: 뒤에 있던 Chrome 원격 데스크톱이 보안 입력을 켜 두어 모든 앱에서
        // 붙여넣기가 멈췄다. 실험으로 그 상태에서도 맨 앞 앱에 ⌘V가 들어가는 것을 확인했다
        XCTAssertNil(PasteBlock(trusted: true, secureInputOn: true,
                                heldInBackground: true, passwordFieldFocused: false))
    }

    func testPasswordFieldBlocksEvenWhenSecureInputIsHeldInBackground() {
        // 켠 앱이 뒤에 있어도, 지금 커서가 암호 칸이면 받아쓴 글을 넣지 않는다
        XCTAssertEqual(PasteBlock(trusted: true, secureInputOn: true,
                                  heldInBackground: true, passwordFieldFocused: true), .secureInput)
    }

    func testSecureInputHeldByFrontAppOrUnknownBlocks() {
        // 맨 앞 앱이 켰거나(그 앱의 암호 칸) 누가 켰는지 모르면 지금처럼 클립보드에만 담는다
        XCTAssertEqual(PasteBlock(trusted: true, secureInputOn: true,
                                  heldInBackground: false, passwordFieldFocused: false), .secureInput)
    }

    func testMissingPermissionComesFirst() {
        // 권한이 없으면 보안 입력 상태와 관계없이 ⌘V를 보낼 수 없다 — 권한 안내가 맞다
        XCTAssertEqual(PasteBlock(trusted: false, secureInputOn: true,
                                  heldInBackground: false, passwordFieldFocused: false), .noAccessibility)
        XCTAssertEqual(PasteBlock(trusted: false, secureInputOn: true,
                                  heldInBackground: true, passwordFieldFocused: false), .noAccessibility)
        XCTAssertEqual(PasteBlock(trusted: false, secureInputOn: false,
                                  heldInBackground: false, passwordFieldFocused: false), .noAccessibility)
    }
}
