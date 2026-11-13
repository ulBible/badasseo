import XCTest
@testable import BadasseoCore

final class LateResultPolicyTests: XCTestCase {
    private func decide(keyUp: Int32? = 501, now: Int32? = 501,
                        elapsed: TimeInterval = 0.6, audio: TimeInterval = 4) -> LateResultPolicy.Decision {
        LateResultPolicy.decide(frontmostAtKeyUp: keyUp, frontmostNow: now,
                                elapsedSeconds: elapsed, audioSeconds: audio)
    }

    func testSameFrontmostAppInsertsAndSendsCommand() {
        XCTAssertEqual(decide(), .insert(sendCommand: true))
    }

    /// 전사가 끝났을 때 다른 앱이 앞에 있으면 거기에 붙여넣거나 Return을 보내면 안 된다.
    func testDifferentFrontmostAppOnlyCopies() {
        XCTAssertEqual(decide(now: 777), .copyOnly)
    }

    func testUnknownOnBothSidesInserts() {
        XCTAssertEqual(decide(keyUp: nil, now: nil), .insert(sendCommand: true))
    }

    func testUnknownOnOneSideOnlyCopies() {
        XCTAssertEqual(decide(now: nil), .copyOnly)
        XCTAssertEqual(decide(keyUp: nil), .copyOnly)
    }

    /// 같은 앱이라도 한참 뒤에 끝났으면 그사이 다른 창·대화방으로 옮겼을 수 있다 —
    /// 텍스트는 넣되 Return 같은 명령 키는 보내지 않는다.
    func testVeryLateResultInsertsButWithholdsCommand() {
        XCTAssertEqual(decide(elapsed: 10.5, audio: 4), .insert(sendCommand: false))
    }

    func testResultWithinDeadlineStillSendsCommand() {
        XCTAssertEqual(decide(elapsed: 9.5, audio: 4), .insert(sendCommand: true))
    }

    /// 긴 받아쓰기는 정상적으로도 오래 걸린다 — 길이에 비례해 기한을 늘린다.
    func testLongDictationGetsProportionallyLongerDeadline() {
        XCTAssertEqual(decide(elapsed: 30, audio: 120), .insert(sendCommand: true))
        XCTAssertEqual(decide(elapsed: 61, audio: 120), .insert(sendCommand: false))
    }
}
