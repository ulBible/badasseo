import Foundation

/// 전사가 끝났을 때 결과를 커서 위치에 넣어도 되는지.
///
/// 전사가 오래 걸리면 그사이 사용자가 다른 앱으로 넘어갈 수 있다. 그 앱에 텍스트를
/// 붙여넣거나 음성 명령의 Return을 보내면 엉뚱한 곳에 입력된다 — 키를 뗀 시점의 앱이
/// 여전히 앞에 있을 때만 넣고, 아니면 클립보드에만 담는다.
public enum LateResultPolicy {
    public enum Decision: Equatable, Sendable {
        /// 커서 위치에 넣는다. `sendCommand`가 false면 음성 명령 키(Return 등)는 보내지 않는다.
        case insert(sendCommand: Bool)
        /// 붙여넣지 않고 클립보드에만 담는다.
        case copyOnly
    }

    /// 키를 뗀 뒤 이 시간 안에 끝난 전사만 명령 키까지 보낸다. 같은 앱이 앞에 있어도 한참
    /// 뒤라면 그사이 다른 창이나 대화방으로 옮겼을 수 있고, 거기에 Return이 들어가면 되돌릴
    /// 수 없다. 긴 받아쓰기는 정상적으로도 오래 걸리므로 길이의 절반까지 기다려 준다.
    public static func commandDeadline(audioSeconds: TimeInterval) -> TimeInterval {
        max(10, audioSeconds / 2)
    }

    public static func decide(frontmostAtKeyUp: Int32?, frontmostNow: Int32?,
                              elapsedSeconds: TimeInterval, audioSeconds: TimeInterval) -> Decision {
        guard frontmostAtKeyUp == frontmostNow else { return .copyOnly }
        return .insert(sendCommand: elapsedSeconds <= commandDeadline(audioSeconds: audioSeconds))
    }
}
