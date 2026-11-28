import XCTest
@testable import BadasseoCore

final class PasteBlockTests: XCTestCase {
    func testNothingBlocksWhenTrustedAndSecureInputOff() {
        XCTAssertNil(PasteBlock(trusted: true, secureInputOn: false, focusedField: .unknown, focusedAppIsTerminal: nil))
    }

    func testSecureInputDoesNotBlockAPlainTextFieldOutsideTerminals() {
        // 2026-11-27·28 실사용: 뒤에 있던 Chrome 원격 데스크톱이 보안 입력을 켜 두어 모든 앱에서
        // 붙여넣기가 멈췄다. 그 상태에서도 맨 앞 앱에 ⌘V가 들어간다(11/27 실험). 누가 켰는지는 묻지 않는다 —
        // macOS가 알려 주는 값을 믿을 수 없다(11/28 실험, PasteBlock 설명)
        XCTAssertNil(PasteBlock(trusted: true, secureInputOn: true, focusedField: .plainText, focusedAppIsTerminal: false))
    }

    func testPasswordFieldBlocks() {
        // 지금 커서가 암호 칸이면 받아쓴 글을 넣지 않는다
        XCTAssertEqual(PasteBlock(trusted: true, secureInputOn: true, focusedField: .password, focusedAppIsTerminal: false),
                       .secureInput)
    }

    func testUnknownFieldBlocks() {
        // 칸을 알아내지 못하면 암호 칸일 수 있다 — 클립보드에만 담는다
        // (11/28 실험: Chromium 앱의 암호 칸은 칸 종류를 내주지 않았다)
        XCTAssertEqual(PasteBlock(trusted: true, secureInputOn: true, focusedField: .unknown, focusedAppIsTerminal: false),
                       .secureInput)
    }

    func testTerminalBlocksWhileSecureInputIsOnEvenInAPlainTextField() {
        // 터미널 본문은 sudo·ssh 암호 프롬프트에서도 AXTextArea로 읽혀 암호 칸인지 알 수 없다 —
        // 받아쓴 글이 암호 프롬프트에 들어가고 음성 명령이면 엔터까지 눌린다
        XCTAssertEqual(PasteBlock(trusted: true, secureInputOn: true, focusedField: .plainText, focusedAppIsTerminal: true),
                       .secureInput)
    }

    func testUnknownAppBlocksWhileSecureInputIsOn() {
        // 칸이 어느 앱에 있는지 모르면 터미널일 수 있다
        XCTAssertEqual(PasteBlock(trusted: true, secureInputOn: true, focusedField: .plainText, focusedAppIsTerminal: nil),
                       .secureInput)
    }

    func testTerminalIsNotBlockedWhenSecureInputIsOff() {
        // 보안 입력이 꺼져 있으면 지금처럼 터미널에도 붙여넣는다
        XCTAssertNil(PasteBlock(trusted: true, secureInputOn: false, focusedField: .plainText, focusedAppIsTerminal: true))
    }

    func testMissingPermissionComesFirst() {
        // 권한이 없으면 보안 입력 상태와 관계없이 ⌘V를 보낼 수 없다 — 권한 안내가 맞다
        XCTAssertEqual(PasteBlock(trusted: false, secureInputOn: true, focusedField: .unknown, focusedAppIsTerminal: nil),
                       .noAccessibility)
        XCTAssertEqual(PasteBlock(trusted: false, secureInputOn: true, focusedField: .plainText, focusedAppIsTerminal: true),
                       .noAccessibility)
        XCTAssertEqual(PasteBlock(trusted: false, secureInputOn: false, focusedField: .plainText, focusedAppIsTerminal: false),
                       .noAccessibility)
    }

    // MARK: - TerminalApps

    func testKnownTerminalsAreTerminals() {
        // 2026-11-28 설치본에서 mdls로 확인한 번들 ID
        XCTAssertEqual(TerminalApps.isTerminal(bundleID: "com.apple.Terminal"), true)
        XCTAssertEqual(TerminalApps.isTerminal(bundleID: "com.googlecode.iterm2"), true)
    }

    func testBundleIDMatchIgnoresCase() {
        XCTAssertEqual(TerminalApps.isTerminal(bundleID: "COM.APPLE.TERMINAL"), true)
    }

    func testIDEsAndOtherAppsAreNotTerminals() {
        // IDE 안의 터미널은 넣지 않는다 — 넣으면 IDE 전체가 막힌다
        XCTAssertEqual(TerminalApps.isTerminal(bundleID: "com.microsoft.VSCode"), false)
        XCTAssertEqual(TerminalApps.isTerminal(bundleID: "com.google.antigravity-ide"), false)
        XCTAssertEqual(TerminalApps.isTerminal(bundleID: "com.tinyspeck.slackmacgap"), false)
    }

    func testUnknownBundleIDIsUnknown() {
        XCTAssertNil(TerminalApps.isTerminal(bundleID: nil))
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
