import XCTest
@testable import BadasseoCore

private final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var t: TimeInterval = 0
    var now: TimeInterval { lock.lock(); defer { lock.unlock() }; return t }
    func advance(_ seconds: TimeInterval) { lock.lock(); t += seconds; lock.unlock() }
}

private final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var n = 0
    var value: Int { lock.lock(); defer { lock.unlock() }; return n }
    @discardableResult func increment() -> Int { lock.lock(); defer { lock.unlock() }; n += 1; return n }
}

private final class FakeEngine {
    let id: Int
    private let freed: Counter
    init(id: Int, freed: Counter) { self.id = id; self.freed = freed }
    deinit { freed.increment() }
}

private struct LoadFailed: Error {}
private struct BodyFailed: Error {}

final class EngineHostTests: XCTestCase {
    private let clock = TestClock()
    private let loads = Counter()
    private let freed = Counter()

    /// `failFirst`번째까지의 로드는 실패한다.
    private func makeHost(failFirst: Int = 0) -> EngineHost<FakeEngine> {
        let (clock, loads, freed) = (clock, loads, freed)
        return EngineHost(clock: { clock.now }) {
            let n = loads.increment()
            if n <= failFirst { throw LoadFailed() }
            return FakeEngine(id: n, freed: freed)
        }
    }

    func testRunLoadsEngineOnFirstUse() async throws {
        let host = makeHost()
        let info = try await host.run { _, info in info }
        XCTAssertEqual(loads.value, 1)
        XCTAssertTrue(info.loadedNow)
    }

    func testSecondRunReusesLoadedEngine() async throws {
        let host = makeHost()
        let first = try await host.run { engine, _ in engine.id }
        let (second, info) = try await host.run { engine, info in (engine.id, info) }
        XCTAssertEqual(loads.value, 1)
        XCTAssertEqual(first, second)
        XCTAssertFalse(info.loadedNow)
    }

    func testPrepareLoadsEngineBeforeRun() async throws {
        let host = makeHost()
        host.prepare()
        let info = try await host.run { _, info in info }
        XCTAssertEqual(loads.value, 1)
        XCTAssertFalse(info.loadedNow, "prepare가 이미 올려 둔 엔진을 써야 한다")
    }

    func testConcurrentPrepareAndRunsLoadOnce() async throws {
        let host = makeHost()
        try await withThrowingTaskGroup(of: Int.self) { group in
            for _ in 0..<8 {
                host.prepare()
                group.addTask { try await host.run { engine, _ in engine.id } }
            }
            for try await id in group { XCTAssertEqual(id, 1) }
        }
        XCTAssertEqual(loads.value, 1)
    }

    func testLoadFailureIsThrownAndNextRunRetries() async throws {
        let host = makeHost(failFirst: 1)
        do {
            _ = try await host.run { engine, _ in engine.id }
            XCTFail("로드 실패가 run에서 던져져야 한다")
        } catch is LoadFailed {}
        let id = try await host.run { engine, _ in engine.id }
        XCTAssertEqual(id, 2)
        XCTAssertEqual(loads.value, 2)
    }

    func testPrepareSwallowsLoadFailureAndRunRetries() async throws {
        let host = makeHost(failFirst: 1)
        host.prepare()
        let id = try await host.run { engine, _ in engine.id }
        XCTAssertEqual(id, 2)
    }

    func testBodyErrorIsPropagatedAndEngineIsKept() async throws {
        let host = makeHost()
        do {
            try await host.run { _, _ in throw BodyFailed() }
            XCTFail("body의 에러가 전달돼야 한다")
        } catch is BodyFailed {}
        _ = try await host.run { engine, _ in engine.id }
        XCTAssertEqual(loads.value, 1)
    }

    func testUnloadIfIdleFreesEngineAfterMinIdle() async throws {
        let host = makeHost()
        _ = try await host.run { engine, _ in engine.id }
        clock.advance(31)
        let result = await host.unloadIfIdle(minIdle: 30)
        XCTAssertEqual(result, .unloaded)
        XCTAssertEqual(freed.value, 1, "엔진이 실제로 해제돼야 한다")
        let info = try await host.run { _, info in info }
        XCTAssertTrue(info.loadedNow)
        XCTAssertEqual(loads.value, 2)
    }

    func testUnloadIfIdleKeepsRecentlyUsedEngine() async throws {
        let host = makeHost()
        _ = try await host.run { engine, _ in engine.id }
        clock.advance(29)
        let result = await host.unloadIfIdle(minIdle: 30)
        XCTAssertEqual(result, .stillInUse)
        XCTAssertEqual(freed.value, 0)
    }

    func testUnloadIfIdleWithoutEngineReportsNotLoaded() async {
        let host = makeHost()
        let result = await host.unloadIfIdle(minIdle: 30)
        XCTAssertEqual(result, .notLoaded)
    }

    /// 키를 누르는 순간의 prepare가 뒤늦게 도착한 해제 요청보다 먼저 큐에 들어가면,
    /// 방금 준비한 엔진이 해제되면 안 된다.
    func testPrepareCountsAsUse() async throws {
        let host = makeHost()
        _ = try await host.run { engine, _ in engine.id }
        clock.advance(600)
        host.prepare()
        let result = await host.unloadIfIdle(minIdle: 30)
        XCTAssertEqual(result, .stillInUse)
    }

    func testRunReportsSecondsSinceLoad() async throws {
        let host = makeHost()
        _ = try await host.run { engine, _ in engine.id }
        clock.advance(2.5)
        let info = try await host.run { _, info in info }
        XCTAssertEqual(info.secondsSinceLoad, 2.5, accuracy: 0.001)
    }
}
