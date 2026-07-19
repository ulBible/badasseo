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

    // 관측된 환각: 오디오 끝자락 0.24초 세그먼트가 직전 문장(20+자)을 반복.
    func testTailHallucinationIsImpossiblyDense() {
        XCTAssertTrue(SpeechGate.isImpossiblyDense(
            "14번 마지막 문장까지 빠짐없이 전사되기를 바랍니다", duration: 0.24))
        XCTAssertTrue(SpeechGate.isImpossiblyDense("긴 문장이 순간에 나올 수 없다", duration: 0))
    }
    func testRealSpeechDensityIsKept() {
        XCTAssertFalse(SpeechGate.isImpossiblyDense("네", duration: 0.2))            // 짧은 대답
        XCTAssertFalse(SpeechGate.isImpossiblyDense("알겠습니다", duration: 0.9))      // 빠른 발화
        XCTAssertFalse(SpeechGate.isImpossiblyDense(
            "일 초 이상 세그먼트는 밀도와 무관하게 통과합니다", duration: 1.0))
    }
}
