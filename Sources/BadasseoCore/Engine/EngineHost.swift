import Foundation

/// `EngineHost.run`이 시작될 때 엔진이 어떤 상태였는지 — 지연 로그용.
public struct EngineRunInfo: Sendable, Equatable {
    /// 이 run이 엔진을 직접 로드했다 (= 준비가 안 된 채로 전사 요청이 왔다).
    public let loadedNow: Bool
    /// 엔진이 로드된 뒤 지난 시간(초).
    public let secondsSinceLoad: TimeInterval
}

/// 무거운 엔진 하나(whisper 컨텍스트, 약 1.8GB)를 직렬 큐로 소유한다.
///
/// 로드·사용·해제가 모두 같은 큐에서 차례로 일어나므로 엔진에 동시에 접근하는 일이
/// 구조적으로 없다(whisper_context는 스레드 안전하지 않다). 큐가 순서를 보장하므로
/// 로드가 끝나기 전에 전사를 요청해도 그 로드를 기다렸다가 같은 엔진을 쓴다 — 엔진이
/// 둘 생기지 않는다.
///
/// 엔진은 큐 밖으로 내보내지 않는다 — `run`의 `body`는 엔진을 반환하거나 다른 곳에 보관하면
/// 안 된다(그러면 해제가 큐 밖에서 일어나거나 엔진이 동시에 쓰일 수 있다).
///
/// `@unchecked Sendable`: 가변 상태(`engine`·`loadedAt`·`lastUse`)는 `queue` 위에서만
/// 읽고 쓴다.
public final class EngineHost<Engine>: @unchecked Sendable {
    public enum UnloadResult: Sendable, Equatable { case unloaded, stillInUse, notLoaded }

    static var queueLabel: String { "app.badasseo.engine" }
    private let queue = DispatchQueue(label: queueLabel, qos: .userInitiated)
    private let clock: @Sendable () -> TimeInterval
    private let load: @Sendable () throws -> Engine
    private var engine: Engine?
    private var loadedAt: TimeInterval = 0
    private var lastUse: TimeInterval = 0

    public init(clock: @escaping @Sendable () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
                load: @escaping @Sendable () throws -> Engine) {
        self.clock = clock
        self.load = load
    }

    deinit {
        // 호스트의 마지막 참조가 어느 스레드에서 사라지든 엔진 해제는 엔진 큐에서 한다.
        // (큐에 남은 작업은 self를 붙잡고 있으므로, 여기 왔다면 큐는 비어 있다.)
        let handoff = Handoff(engine)
        engine = nil
        queue.async { handoff.engine = nil }
    }

    /// 엔진의 마지막 참조를 큐로 넘겨 거기서 놓게 하는 상자.
    private final class Handoff: @unchecked Sendable {
        var engine: Engine?
        init(_ engine: Engine?) { self.engine = engine }
    }

    /// 엔진이 없으면 미리 로드한다. 실패는 삼킨다 — 뒤따르는 `run`이 다시 시도해 에러를 낸다.
    ///
    /// `minIdle`을 주면, 올라와 있는 엔진이라도 그만큼 쉬었으면 버리고 새로 로드한다 —
    /// 오래 쉰 엔진의 메모리는 스왑으로 나갔을 수 있고, 그걸 되읽는 것보다 파일에서 새로
    /// 읽는 쪽이 빠르다.
    public func prepare(dropIfIdleFor minIdle: TimeInterval? = nil) {
        queue.async {
            if let minIdle, self.engine != nil, self.clock() - self.lastUse >= minIdle {
                self.engine = nil
            }
            _ = try? self.loadedEngine()
            self.lastUse = self.clock()
        }
    }

    /// 엔진을 (없으면 로드해서) `body`에 넘긴다. `body`는 엔진 큐에서 실행된다.
    public func run<T: Sendable>(
        _ body: @escaping @Sendable (Engine, EngineRunInfo) throws -> T
    ) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                continuation.resume(with: Result {
                    let (engine, loadedNow) = try self.loadedEngine()
                    let info = EngineRunInfo(loadedNow: loadedNow,
                                             secondsSinceLoad: self.clock() - self.loadedAt)
                    defer { self.lastUse = self.clock() }
                    return try body(engine, info)
                })
            }
        }
    }

    /// `minIdle`초 넘게 쓰이지 않았으면 엔진을 해제한다. 쉰 시간은 큐 위에서 판정하므로,
    /// 이 요청보다 먼저 큐에 들어온 `prepare`·`run`이 있으면 해제하지 않는다.
    public func unloadIfIdle(minIdle: TimeInterval) async -> UnloadResult {
        await withCheckedContinuation { continuation in
            queue.async {
                guard self.engine != nil else { return continuation.resume(returning: .notLoaded) }
                guard self.clock() - self.lastUse >= minIdle else {
                    return continuation.resume(returning: .stillInUse)
                }
                self.engine = nil
                continuation.resume(returning: .unloaded)
            }
        }
    }

    private func loadedEngine() throws -> (Engine, loadedNow: Bool) {
        if let engine { return (engine, false) }
        let fresh = try load()
        engine = fresh
        loadedAt = clock()
        return (fresh, true)
    }
}
