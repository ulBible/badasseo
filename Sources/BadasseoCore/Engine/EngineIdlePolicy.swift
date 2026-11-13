import Darwin
import Foundation

/// 쉬는 엔진을 언제 내려놓을지.
///
/// 엔진의 모델 메모리(약 1.8GB)는 쓰지 않는 동안 macOS가 압축하고, 메모리가 모자라면
/// 디스크 스왑으로 내보낸다. 그러면 다음 받아쓰기는 그만큼을 스왑에서 다시 읽느라
/// 수 초를 기다린다(실측 5~13초). 모델 파일에서 새로 읽는 쪽이 훨씬 빠르므로(약 0.5초,
/// 키를 누르는 순간 시작해 말하는 시간에 묻힌다), 쉬는 엔진은 해제해 두고 다시 로드한다.
public enum EngineIdlePolicy {
    /// 메모리 압박 중에는 이 시간 넘게 쓰이지 않으면 해제한다. 압박 속에서는 쉬는 모델이
    /// 1분 안에 스왑으로 나가기 시작한다(실측: 35초에 86MB, 57초에 882MB).
    public static let pressuredIdleSeconds: TimeInterval = 30
    /// 압박이 없을 때는 이 시간 넘게 쓰이지 않으면 해제한다. 압박 레벨이 정상인 채로도 스왑은
    /// 일어날 수 있고(실측: 26분 쉰 뒤 4초), 오래 쓰지 않는 동안 1.8GB를 시스템에 돌려준다.
    /// 압박 레벨을 읽지 못할 때도 이 값을 쓴다.
    public static let relaxedIdleSeconds: TimeInterval = 600
    /// 해제 여부를 다시 확인하는 주기.
    public static let checkInterval: TimeInterval = 15

    /// 지금 압박 레벨에서, 엔진이 얼마나 쉬면 내려놓을지.
    public static func minIdleSeconds(pressureLevel: Int32) -> TimeInterval {
        isUnderPressure(level: pressureLevel) ? pressuredIdleSeconds : relaxedIdleSeconds
    }

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
