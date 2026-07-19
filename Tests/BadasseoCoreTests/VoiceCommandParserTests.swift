import XCTest
@testable import BadasseoCore

final class VoiceCommandParserTests: XCTestCase {
    private let defaults: [VoiceCommand: [String]] = [
        .enter: ["엔터"], .newline: ["줄바꿈"], .tab: ["탭"], .cancel: ["취소"],
    ]

    func testTrailingKeywordMatchesAndIsStripped() {
        let r = VoiceCommandParser.parse("메시지 보내줘 엔터", triggers: defaults)
        XCTAssertEqual(r.command, .enter)
        XCTAssertEqual(r.text, "메시지 보내줘")
    }
    func testAllFourCommands() {
        XCTAssertEqual(VoiceCommandParser.parse("안녕 줄바꿈", triggers: defaults).command, .newline)
        XCTAssertEqual(VoiceCommandParser.parse("안녕 탭", triggers: defaults).command, .tab)
        XCTAssertEqual(VoiceCommandParser.parse("안녕 취소", triggers: defaults).command, .cancel)
    }
    func testTrailingPunctuationIgnored() {
        let r = VoiceCommandParser.parse("보내줘 엔터.", triggers: defaults)
        XCTAssertEqual(r.command, .enter)
        XCTAssertEqual(r.text, "보내줘")
    }
    func testCommaBeforeKeywordRemoved() {
        let r = VoiceCommandParser.parse("확인했습니다, 엔터", triggers: defaults)
        XCTAssertEqual(r.command, .enter)
        XCTAssertEqual(r.text, "확인했습니다")
    }
    func testInnerPunctuationPreserved() {
        let r = VoiceCommandParser.parse("메모 작성했습니다. 엔터", triggers: defaults)
        XCTAssertEqual(r.command, .enter)
        XCTAssertEqual(r.text, "메모 작성했습니다.")
    }
    func testTwoTokenTriggerJoined() {
        // whisper가 "줄바꿈"을 "줄 바꿈"으로 띄어 전사하는 경우
        let r = VoiceCommandParser.parse("첫 줄입니다 줄 바꿈", triggers: defaults)
        XCTAssertEqual(r.command, .newline)
        XCTAssertEqual(r.text, "첫 줄입니다")
    }
    func testNoCommandPassesThrough() {
        let r = VoiceCommandParser.parse("오늘 회의는 세 시입니다", triggers: defaults)
        XCTAssertNil(r.command)
        XCTAssertEqual(r.text, "오늘 회의는 세 시입니다")
    }
    func testKeywordMidSentenceDoesNotTrigger() {
        let r = VoiceCommandParser.parse("엔터 키를 눌러 주세요", triggers: defaults)
        XCTAssertNil(r.command)
    }
    func testCommandOnlyUtteranceReturnsEmptyText() {
        let r = VoiceCommandParser.parse("엔터", triggers: defaults)
        XCTAssertEqual(r.command, .enter)
        XCTAssertEqual(r.text, "")
    }
    func testSynonymTriggers() {
        var t = defaults
        t[.enter] = ["엔터", "전송", "보내기"]
        XCTAssertEqual(VoiceCommandParser.parse("답장 완료 전송", triggers: t).command, .enter)
        XCTAssertEqual(VoiceCommandParser.parse("답장 완료 보내기", triggers: t).command, .enter)
    }
    func testCustomTriggerWithSpaceNormalized() {
        var t = defaults
        t[.enter] = ["보내 줘"]
        let r = VoiceCommandParser.parse("답장 보내 줘", triggers: t)
        XCTAssertEqual(r.command, .enter)
        XCTAssertEqual(r.text, "답장")
    }
    func testDuplicateWordFirstCommandWins() {
        var t = defaults
        t[.enter] = ["끝"]; t[.cancel] = ["끝"]
        XCTAssertEqual(VoiceCommandParser.parse("입력 끝", triggers: t).command, .enter)
    }
    func testEmptyTriggerListDisablesCommand() {
        var t = defaults
        t[.enter] = []
        XCTAssertNil(VoiceCommandParser.parse("보내줘 엔터", triggers: t).command)
    }
    func testLatinTriggerCaseInsensitive() {
        var t = defaults
        t[.enter] = ["go"]
        XCTAssertEqual(VoiceCommandParser.parse("검색 실행 Go", triggers: t).command, .enter)
    }
}
