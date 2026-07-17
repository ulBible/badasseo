import XCTest
@testable import BadasseoCore

final class HoldKeyTests: XCTestCase {
    func testKeyCodeDeviceMaskAndDisplayName() {
        let table: [(HoldKey, UInt16, UInt?, String)] = [
            (.rightCommand, 54, 0x0010, "우측 ⌘"),
            (.rightOption, 61, 0x0040, "우측 ⌥"),
            (.rightControl, 62, 0x2000, "우측 ⌃"),
            (.fn, 63, nil, "🌐 fn"),
        ]
        for (key, keyCode, deviceMask, displayName) in table {
            XCTAssertEqual(key.keyCode, keyCode, "\(key) keyCode")
            XCTAssertEqual(key.deviceMask, deviceMask, "\(key) deviceMask")
            XCTAssertEqual(key.displayName, displayName, "\(key) displayName")
        }
    }

    func testCurrentDefaultsToRightCommand() {
        UserDefaults.standard.removeObject(forKey: HoldKey.defaultsKey)
        XCTAssertEqual(HoldKey.current, .rightCommand)
    }

    func testCurrentReflectsUserDefaults() {
        UserDefaults.standard.set(HoldKey.rightOption.rawValue, forKey: HoldKey.defaultsKey)
        XCTAssertEqual(HoldKey.current, .rightOption)
        UserDefaults.standard.removeObject(forKey: HoldKey.defaultsKey)
    }
}
