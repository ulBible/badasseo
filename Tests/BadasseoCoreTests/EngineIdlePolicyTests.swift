import XCTest
@testable import BadasseoCore

final class EngineIdlePolicyTests: XCTestCase {
    func testNormalPressureIsNotPressure() {
        XCTAssertFalse(EngineIdlePolicy.isUnderPressure(level: 1))
    }

    func testWarningAndCriticalAreUnderPressure() {
        XCTAssertTrue(EngineIdlePolicy.isUnderPressure(level: 2))
        XCTAssertTrue(EngineIdlePolicy.isUnderPressure(level: 4))
    }

    /// sysctl을 읽지 못하면(0) 압박으로 보지 않는다 — 긴 유휴 기준을 쓴다.
    func testUnreadableLevelIsNotPressure() {
        XCTAssertFalse(EngineIdlePolicy.isUnderPressure(level: 0))
        XCTAssertFalse(EngineIdlePolicy.isUnderPressure(level: -1))
    }

    /// 압박 중에는 모델이 금방 스왑으로 나가므로(실측: 57초에 절반) 짧게 쉬어도 내려놓는다.
    func testIdleLimitIsShortUnderPressure() {
        XCTAssertEqual(EngineIdlePolicy.minIdleSeconds(pressureLevel: 2), 30)
        XCTAssertEqual(EngineIdlePolicy.minIdleSeconds(pressureLevel: 4), 30)
    }

    /// 압박이 없어도(또는 레벨을 읽지 못해도) 오래 쉬면 내려놓는다 — 레벨이 정상인 채로도
    /// 스왑은 일어날 수 있다.
    func testIdleLimitIsTenMinutesWithoutPressure() {
        XCTAssertEqual(EngineIdlePolicy.minIdleSeconds(pressureLevel: 1), 600)
        XCTAssertEqual(EngineIdlePolicy.minIdleSeconds(pressureLevel: 0), 600)
    }

    func testCurrentPressureLevelIsAKnownValue() {
        XCTAssertTrue([1, 2, 4].contains(MemoryPressure.currentLevel()),
                      "kern.memorystatus_vm_pressure_level은 1·2·4 중 하나")
    }
}
