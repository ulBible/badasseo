import XCTest
@testable import BadasseoCore

final class PasteBlockTests: XCTestCase {
    func testNothingBlocksWhenTrustedAndSecureInputOff() {
        XCTAssertNil(PasteBlock(trusted: true, secureInputOn: false,
                                heldInBackground: false, focusedField: .unknown))
    }

    func testBackgroundSecureInputDoesNotBlockAPlainTextField() {
        // 2026-11-27 실사용: 뒤에 있던 Chrome 원격 데스크톱이 보안 입력을 켜 두어 모든 앱에서
        // 붙여넣기가 멈췄다. 실험으로 그 상태에서도 맨 앞 앱에 ⌘V가 들어가는 것을 확인했다
        XCTAssertNil(PasteBlock(trusted: true, secureInputOn: true,
                                heldInBackground: true, focusedField: .plainText))
    }

    func testPasswordFieldBlocksEvenWhenSecureInputIsHeldInBackground() {
        // 켠 앱이 뒤에 있어도, 지금 커서가 암호 칸이면 받아쓴 글을 넣지 않는다
        XCTAssertEqual(PasteBlock(trusted: true, secureInputOn: true,
                                  heldInBackground: true, focusedField: .password), .secureInput)
    }

    func testUnknownFieldBlocksEvenWhenSecureInputIsHeldInBackground() {
        // Electron 앱처럼 칸을 알아내지 못하면 암호 칸일 수 있다 — 클립보드에만 담는다
        XCTAssertEqual(PasteBlock(trusted: true, secureInputOn: true,
                                  heldInBackground: true, focusedField: .unknown), .secureInput)
    }

    func testSecureInputHeldByFrontAppOrUnknownBlocks() {
        // 맨 앞 앱이 켰거나(그 앱의 암호 칸) 누가 켰는지 모르면 지금처럼 클립보드에만 담는다
        XCTAssertEqual(PasteBlock(trusted: true, secureInputOn: true,
                                  heldInBackground: false, focusedField: .plainText), .secureInput)
    }

    func testMissingPermissionComesFirst() {
        // 권한이 없으면 보안 입력 상태와 관계없이 ⌘V를 보낼 수 없다 — 권한 안내가 맞다
        XCTAssertEqual(PasteBlock(trusted: false, secureInputOn: true,
                                  heldInBackground: false, focusedField: .unknown), .noAccessibility)
        XCTAssertEqual(PasteBlock(trusted: false, secureInputOn: true,
                                  heldInBackground: true, focusedField: .plainText), .noAccessibility)
        XCTAssertEqual(PasteBlock(trusted: false, secureInputOn: false,
                                  heldInBackground: false, focusedField: .plainText), .noAccessibility)
    }

    // MARK: - heldInBackground

    func testHeldInBackgroundOnlyWhenRecordedAppIsNeitherFrontNorFocused() {
        XCTAssertTrue(PasteBlock.heldInBackground(recordedPID: 300, frontmostPID: 100, focusedPID: 100))
    }

    func testRecordedFrontAppIsNotBackground() {
        // 기록 값은 대개 맨 앞 앱을 따라간다(2026-11-27 실험) — 누가 켰는지 모르는 것으로 본다
        XCTAssertFalse(PasteBlock.heldInBackground(recordedPID: 100, frontmostPID: 100, focusedPID: 100))
    }

    func testNonActivatingPanelThatHoldsSecureInputIsNotBackground() {
        // 암호 관리자의 빠른 입력 창: 맨 앞 앱은 Safari(100)인데 키보드 입력은 그 창(200)이 받고,
        // 보안 입력도 그 창이 켰다 — 맨 앞 앱만 보면 뒤의 것으로 오판한다
        XCTAssertFalse(PasteBlock.heldInBackground(recordedPID: 200, frontmostPID: 100, focusedPID: 200))
    }

    func testAnythingUnknownIsNotBackground() {
        XCTAssertFalse(PasteBlock.heldInBackground(recordedPID: nil, frontmostPID: 100, focusedPID: 100))
        XCTAssertFalse(PasteBlock.heldInBackground(recordedPID: 300, frontmostPID: nil, focusedPID: 100))
        XCTAssertFalse(PasteBlock.heldInBackground(recordedPID: 300, frontmostPID: 100, focusedPID: nil))
    }

    // MARK: - FocusedField

    func testPlainTextFieldsWithOrWithoutSubrole() {
        // 보통 입력 칸은 하위 역할이 없거나(NSTextField·NSTextView) 다른 하위 역할(검색 칸)이다
        XCTAssertEqual(FocusedField(role: .value("AXTextField"), subrole: .absent), .plainText)
        XCTAssertEqual(FocusedField(role: .value("AXTextArea"), subrole: .absent), .plainText)
        XCTAssertEqual(FocusedField(role: .value("AXTextField"), subrole: .value("AXSearchField")), .plainText)
        XCTAssertEqual(FocusedField(role: .value("AXComboBox"), subrole: .absent), .plainText)
    }

    func testSecureTextFieldIsPassword() {
        XCTAssertEqual(FocusedField(role: .value("AXTextField"), subrole: .value("AXSecureTextField")), .password)
    }

    func testUnreadableOrNonTextFieldsAreUnknown() {
        // 역할이나 하위 역할을 읽지 못했거나, 글이 어디로 갈지 모르는 요소(창·웹 영역)
        XCTAssertEqual(FocusedField(role: .failed, subrole: .absent), .unknown)
        XCTAssertEqual(FocusedField(role: .absent, subrole: .absent), .unknown)
        XCTAssertEqual(FocusedField(role: .value("AXTextField"), subrole: .failed), .unknown)
        XCTAssertEqual(FocusedField(role: .value("AXWebArea"), subrole: .absent), .unknown)
        XCTAssertEqual(FocusedField(role: .value("AXWindow"), subrole: .absent), .unknown)
    }
}
