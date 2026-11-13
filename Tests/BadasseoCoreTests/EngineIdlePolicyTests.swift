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

    /// sysctl을 읽지 못하면(0) 압박으로 보지 않는다 — 엔진을 계속 올려 두는 기존 동작으로 남는다.
    func testUnreadableLevelIsNotPressure() {
        XCTAssertFalse(EngineIdlePolicy.isUnderPressure(level: 0))
        XCTAssertFalse(EngineIdlePolicy.isUnderPressure(level: -1))
    }

    func testCurrentPressureLevelIsAKnownValue() {
        XCTAssertTrue([1, 2, 4].contains(MemoryPressure.currentLevel()),
                      "kern.memorystatus_vm_pressure_level은 1·2·4 중 하나")
    }
}
