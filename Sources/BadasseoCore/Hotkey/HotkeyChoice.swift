import Foundation

/// 설정의 "누르고 있는 동안 녹음할 키" — 수식키 단독 홀드 4종과 조합 키를 한 목록으로 다룬다.
///
/// 저장은 기존 두 키를 그대로 쓴다: `hotkeyMode`("rightCommand" = 수식키 홀드(레거시 이름),
/// "custom" = 조합 키)와 `HoldKey.defaultsKey`. 새 키를 만들지 않아 기존 사용자 설정과
/// AppState/ModifierHoldMonitor의 판정 로직이 그대로 유지된다.
public enum HotkeyChoice: Hashable {
    case hold(HoldKey)
    case combo

    public static let modeKey = "hotkeyMode"
    static let holdModeValue = "rightCommand"
    static let comboModeValue = "custom"

    /// 저장값 → 선택지. mode 부재는 홀드 모드(AppState 기본값), holdKey 부재·오류는 우측 ⌘.
    public init(mode: String?, holdKey: String?) {
        if mode == Self.comboModeValue {
            self = .combo
        } else {
            self = .hold(HoldKey(rawValue: holdKey ?? "") ?? .rightCommand)
        }
    }

    /// `modeKey`에 저장할 값.
    public var mode: String {
        switch self {
        case .hold: Self.holdModeValue
        case .combo: Self.comboModeValue
        }
    }

    /// `HoldKey.defaultsKey`에 저장할 값. 조합 키는 nil — 이전 홀드 키 선택을 남겨 둔다.
    public var holdKey: HoldKey? {
        if case .hold(let key) = self { return key }
        return nil
    }

    /// 표시 순서. 앱스토어판은 권한 없이 쓰는 조합 키를 맨 위(기본)로.
    public static func options(appStore: Bool) -> [HotkeyChoice] {
        let holds = HoldKey.allCases.map(HotkeyChoice.hold)
        return appStore ? [.combo] + holds : holds + [.combo]
    }

    /// 다른 앱에서 키 감지에 손쉬운 사용 권한이 필요한지 — 홀드 키는 전역 이벤트 모니터를 쓴다.
    public var requiresAccessibility: Bool {
        if case .hold = self { return true }
        return false
    }
}
