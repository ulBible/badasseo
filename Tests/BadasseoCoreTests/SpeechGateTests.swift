import XCTest
@testable import BadasseoCore

final class SpeechGateTests: XCTestCase {
    func testSilenceIsDetected() {
        XCTAssertTrue(SpeechGate.isSilence(samples: [Float](repeating: 0, count: 16000)))
        XCTAssertTrue(SpeechGate.isSilence(samples: (0..<16000).map { _ in Float.random(in: -0.001...0.001) }))
    }
    func testSpeechLevelIsNotSilence() {
        let tone = (0..<16000).map { Float(sin(Double($0) * 2 * .pi * 220 / 16000)) * 0.1 }
        XCTAssertFalse(SpeechGate.isSilence(samples: tone))
    }
    func testEmptyIsSilence() {
        XCTAssertTrue(SpeechGate.isSilence(samples: []))
    }
    func testJunkOutputs() {
        XCTAssertTrue(SpeechGate.isJunk("-."))
        XCTAssertTrue(SpeechGate.isJunk("..."))
        XCTAssertTrue(SpeechGate.isJunk(" - "))
        XCTAssertTrue(SpeechGate.isJunk("♪♪"))
        XCTAssertTrue(SpeechGate.isJunk(""))
    }
    func testRealTextIsNotJunk() {
        XCTAssertFalse(SpeechGate.isJunk("안녕하세요."))
        XCTAssertFalse(SpeechGate.isJunk("3시"))
        XCTAssertFalse(SpeechGate.isJunk("PR 올려줘."))
    }
}
