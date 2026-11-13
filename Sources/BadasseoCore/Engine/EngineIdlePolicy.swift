import Darwin
import Foundation

/// 쉬는 엔진을 언제 내려놓을지.
///
/// 엔진의 모델 메모리(약 1.8GB)는 쓰지 않는 동안 macOS가 압축하고, 메모리가 모자라면
/// 디스크 스왑으로 내보낸다. 그러면 다음 받아쓰기는 그만큼을 스왑에서 다시 읽느라
/// 수 초를 기다린다(실측 5~13초). 모델 파일에서 새로 읽는 쪽이 훨씬 빠르므로(약 1초),
/// 메모리 압박이 있을 때는 쉬는 엔진을 해제해 두고 키를 누를 때 다시 로드한다.
/// 압박이 없으면 해제하지 않는다 — 여유 있는 맥에서는 엔진이 계속 올라와 있다.
public enum EngineIdlePolicy {
    /// 압박 상태에서 이 시간 넘게 쓰이지 않으면 해제한다.
    public static let minIdleSeconds: TimeInterval = 30
    /// 해제 여부를 다시 확인하는 주기.
    public static let checkInterval: TimeInterval = 15

    /// `MemoryPressure.currentLevel()` 값이 경고(2) 이상인가.
    public static func isUnderPressure(level: Int32) -> Bool { level >= 2 }
}

public enum MemoryPressure {
    /// `kern.memorystatus_vm_pressure_level` — 1 정상, 2 경고, 4 위험. 읽지 못하면 0.
    /// (DispatchSource 메모리 압박 이벤트는 레벨이 바뀌어도 오지 않는 경우가 있어 직접 읽는다.)
    public static func currentLevel() -> Int32 {
        var level: Int32 = 0
        var size = MemoryLayout<Int32>.size
        guard sysctlbyname("kern.memorystatus_vm_pressure_level", &level, &size, nil, 0) == 0 else { return 0 }
        return level
    }
}
