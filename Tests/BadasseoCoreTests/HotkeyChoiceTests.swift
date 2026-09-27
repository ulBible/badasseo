import XCTest
@testable import BadasseoCore

final class HotkeyChoiceTests: XCTestCase {
    func testInitFromStoredValues() {
        // hotkeyMode 부재 = 홀드 모드, holdKey 부재·잘못된 값 = 우측 ⌘ (AppState·HoldKey.current 기본값과 동일)
        XCTAssertEqual(HotkeyChoice(mode: nil, holdKey: nil), .hold(.rightCommand))
        XCTAssertEqual(HotkeyChoice(mode: "rightCommand", holdKey: "bogus"), .hold(.rightCommand))
        for key in HoldKey.allCases {
            XCTAssertEqual(HotkeyChoice(mode: "rightCommand", holdKey: key.rawValue), .hold(key), "\(key)")
            XCTAssertEqual(HotkeyChoice(mode: nil, holdKey: key.rawValue), .hold(key), "\(key) mode 부재")
        }
        // 조합 키 모드에서는 holdKey 값과 무관
        XCTAssertEqual(HotkeyChoice(mode: "custom", holdKey: "fn"), .combo)
        XCTAssertEqual(HotkeyChoice(mode: "custom", holdKey: nil), .combo)
    }

    func testStoredValues() {
        XCTAssertEqual(HotkeyChoice.combo.mode, "custom")
        XCTAssertNil(HotkeyChoice.combo.holdKey, "조합 키 선택은 holdKey를 건드리지 않는다")
        for key in HoldKey.allCases {
            XCTAssertEqual(HotkeyChoice.hold(key).mode, "rightCommand", "\(key)")
            XCTAssertEqual(HotkeyChoice.hold(key).holdKey, key)
        }
        XCTAssertEqual(HotkeyChoice.modeKey, "hotkeyMode")
    }

    func testRoundTrip() {
        let all: [HotkeyChoice] = HoldKey.allCases.map(HotkeyChoice.hold) + [.combo]
        for choice in all {
            // 조합 키는 기존 holdKey를 남겨 두므로, 이전 값이 있어도 .combo로 복원돼야 한다
            let back = HotkeyChoice(mode: choice.mode, holdKey: choice.holdKey?.rawValue ?? "rightOption")
            XCTAssertEqual(back, choice, "\(choice)")
        }
    }

    func testOptionsOrderPerVariant() {
        XCTAssertEqual(HotkeyChoice.options(appStore: false),
                       [.hold(.rightCommand), .hold(.rightOption), .hold(.rightControl), .hold(.fn), .combo])
        XCTAssertEqual(HotkeyChoice.options(appStore: true),
                       [.combo, .hold(.rightCommand), .hold(.rightOption), .hold(.rightControl), .hold(.fn)])
    }

    func testRequiresAccessibility() {
        for key in HoldKey.allCases { XCTAssertTrue(HotkeyChoice.hold(key).requiresAccessibility, "\(key)") }
        XCTAssertFalse(HotkeyChoice.combo.requiresAccessibility)
    }
}
