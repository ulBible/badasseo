import Foundation

/// 수식키 단독 홀드 후보 — 외부(비Apple) 키보드에는 우측 ⌘가 없는 경우가 많아 선택형.
public enum HoldKey: String, CaseIterable {
    case rightCommand, rightOption, rightControl, fn

    public var keyCode: UInt16 {
        switch self {
        case .rightCommand: 54
        case .rightOption: 61
        case .rightControl: 62
        case .fn: 63
        }
    }
    /// IOLLEvent.h 디바이스 비트 (fn은 없음 — flags .function으로 판정)
    public var deviceMask: UInt? {
        switch self {
        case .rightCommand: 0x0010   // NX_DEVICERCMDKEYMASK
        case .rightOption: 0x0040    // NX_DEVICERALTKEYMASK
        case .rightControl: 0x2000   // NX_DEVICERCTLKEYMASK
        case .fn: nil
        }
    }
    public var displayName: String {
        switch self {
        case .rightCommand: "우측 ⌘"
        case .rightOption: "우측 ⌥"
        case .rightControl: "우측 ⌃"
        case .fn: "🌐 fn"
        }
    }
    public static let defaultsKey = "holdKey"
    public static var current: HoldKey {
        HoldKey(rawValue: UserDefaults.standard.string(forKey: defaultsKey) ?? "") ?? .rightCommand
    }
}
