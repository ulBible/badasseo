import XCTest
@testable import BadasseoCore

final class VoiceCommandSettingsTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "VoiceCommandSettingsTests")!
        defaults.removePersistentDomain(forName: "VoiceCommandSettingsTests")
    }

    func testEnabledByDefault() {
        XCTAssertTrue(VoiceCommandSettings.isEnabled(defaults))
        defaults.set(false, forKey: VoiceCommandSettings.enabledKey)
        XCTAssertFalse(VoiceCommandSettings.isEnabled(defaults))
    }
    func testDefaultTriggerWhenUnset() {
        XCTAssertEqual(VoiceCommandSettings.words(for: .enter, defaults), ["엔터"])
    }
    func testCommaSeparatedWordsParsedAndTrimmed() {
        defaults.set("엔터, 전송 , 보내기", forKey: VoiceCommandSettings.triggersKey(.enter))
        XCTAssertEqual(VoiceCommandSettings.words(for: .enter, defaults),
                       ["엔터", "전송", "보내기"])
    }
    func testEmptyStringDisablesCommand() {
        defaults.set("  ", forKey: VoiceCommandSettings.triggersKey(.tab))
        XCTAssertEqual(VoiceCommandSettings.words(for: .tab, defaults), [])
    }
    func testTriggersCoversAllCommands() {
        let t = VoiceCommandSettings.triggers(defaults)
        XCTAssertEqual(Set(t.keys), Set(VoiceCommand.allCases))
        XCTAssertEqual(t[.cancel], ["취소"])
    }
}
