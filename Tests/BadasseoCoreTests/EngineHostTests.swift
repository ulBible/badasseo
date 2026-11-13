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

/// 지금 실행 중인 디스패치 큐의 라벨.
private func currentQueueLabel() -> String { String(cString: __dispatch_queue_get_label(nil)) }

private final class Labels: @unchecked Sendable {
    private let lock = NSLock()
    private var items: [String] = []
    var all: [String] { lock.lock(); defer { lock.unlock() }; return items }
    func record(_ label: String) { lock.lock(); items.append(label); lock.unlock() }
}

/// 동시에 살아 있는 엔진 수와 그 최댓값.
private final class LiveCount: @unchecked Sendable {
    private let lock = NSLock()
    private var live = 0
    private var maxLive = 0
    var peak: Int { lock.lock(); defer { lock.unlock() }; return maxLive }
    func born() { lock.lock(); live += 1; maxLive = max(maxLive, live); lock.unlock() }
    func died() { lock.lock(); live -= 1; lock.unlock() }
}

private final class FakeEngine {
    let id: Int
    private let freed: Counter
    private let live: LiveCount
    private let freedOn: Labels
    init(id: Int, freed: Counter, live: LiveCount, freedOn: Labels) {
        self.id = id; self.freed = freed; self.live = live; self.freedOn = freedOn
        live.born()
    }
    deinit { freed.increment(); live.died(); freedOn.record(currentQueueLabel()) }
}

private struct LoadFailed: Error {}
private struct BodyFailed: Error {}

final class EngineHostTests: XCTestCase {
    private let clock = TestClock()
    private let loads = Counter()
    private let freed = Counter()
    private let live = LiveCount()
    private let loadedOn = Labels()
    private let freedOn = Labels()

    /// `failFirst`번째까지의 로드는 실패한다.
    private func makeHost(failFirst: Int = 0) -> EngineHost<FakeEngine> {
        let (clock, loads, freed, live, loadedOn, freedOn) = (clock, loads, freed, live, loadedOn, freedOn)
        return EngineHost(clock: { clock.now }) {
            let n = loads.increment()
            loadedOn.record(currentQueueLabel())
            if n <= failFirst { throw LoadFailed() }
            return FakeEngine(id: n, freed: freed, live: live, freedOn: freedOn)
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

    /// 엔진은 1.8GB다 — 해제와 재로드를 아무리 반복해도 둘이 동시에 살아 있으면 안 된다
    /// (과거 엔진 9개 = 16GB 장애).
    func testNeverMoreThanOneEngineAliveAcrossReloads() async throws {
        let host = makeHost()
        for _ in 0..<20 {
            _ = try await host.run { engine, _ in engine.id }
            let result = await host.unloadIfIdle(minIdle: 0)
            XCTAssertEqual(result, .unloaded)
        }
        XCTAssertEqual(loads.value, 20)
        XCTAssertEqual(live.peak, 1)
    }

    /// whisper 컨텍스트의 생성과 해제(whisper_free)는 전사와 같은 큐에서 일어나야 한다.
    func testEngineIsLoadedAndFreedOnTheEngineQueue() async throws {
        let host = makeHost()
        _ = try await host.run { engine, _ in engine.id }
        _ = await host.unloadIfIdle(minIdle: 0)
        XCTAssertEqual(loadedOn.all, [EngineHost<FakeEngine>.queueLabel])
        XCTAssertEqual(freedOn.all, [EngineHost<FakeEngine>.queueLabel])
    }

    /// 호스트를 버릴 때도 엔진 해제는 엔진 큐에서 — 버린 쪽 스레드(예: 메인)에서 돌면 안 된다.
    func testDroppingTheHostFreesTheEngineOnTheEngineQueue() async throws {
        var host: EngineHost<FakeEngine>? = makeHost()
        _ = try await host?.run { engine, _ in engine.id }
        host = nil
        for _ in 0..<200 where freed.value == 0 { try await Task.sleep(for: .milliseconds(5)) }
        XCTAssertEqual(freedOn.all, [EngineHost<FakeEngine>.queueLabel])
    }

    /// 전사가 도는 중에 들어온 해제 요청은 그 전사 뒤에 줄을 선다 — 방금 쓴 엔진은 쉰 게 아니다.
    func testUnloadQueuedBehindRunningWorkKeepsTheEngine() async throws {
        let host = makeHost()
        let started = DispatchSemaphore(value: 0)
        let finish = DispatchSemaphore(value: 0)
        async let ran: Int = host.run { engine, _ in
            started.signal()
            finish.wait()
            return engine.id
        }
        await withCheckedContinuation { continuation in
            DispatchQueue.global().async { started.wait(); continuation.resume() }
        }
        async let unloaded = host.unloadIfIdle(minIdle: 30)
        try await Task.sleep(for: .milliseconds(20))
        finish.signal()
        let (id, result) = try await (ran, unloaded)
        XCTAssertEqual(id, 1)
        XCTAssertEqual(result, .stillInUse)
        XCTAssertEqual(freed.value, 0)
    }

    /// 오래 쉰 엔진은 메모리가 스왑으로 나갔을 수 있다 — 키를 누를 때 그런 엔진은 버리고
    /// 파일에서 새로 읽는다(스왑에서 되읽는 것보다 빠르다).
    func testPrepareReplacesAnEngineThatIdledTooLong() async throws {
        let host = makeHost()
        _ = try await host.run { engine, _ in engine.id }
        clock.advance(31)
        host.prepare(dropIfIdleFor: 30)
        let (id, info) = try await host.run { engine, info in (engine.id, info) }
        XCTAssertEqual(id, 2)
        XCTAssertFalse(info.loadedNow)
        XCTAssertEqual(freed.value, 1)
        XCTAssertEqual(live.peak, 1)
    }

    func testPrepareKeepsAnEngineUsedRecently() async throws {
        let host = makeHost()
        _ = try await host.run { engine, _ in engine.id }
        clock.advance(10)
        host.prepare(dropIfIdleFor: 30)
        let id = try await host.run { engine, _ in engine.id }
        XCTAssertEqual(id, 1)
        XCTAssertEqual(loads.value, 1)
    }

    func testRunReportsSecondsSinceLoad() async throws {
        let host = makeHost()
        _ = try await host.run { engine, _ in engine.id }
        clock.advance(2.5)
        let info = try await host.run { _, info in info }
        XCTAssertEqual(info.secondsSinceLoad, 2.5, accuracy: 0.001)
    }
}
