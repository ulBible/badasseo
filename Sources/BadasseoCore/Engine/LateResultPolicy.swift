import Foundation

/// 전사가 끝났을 때 결과를 커서 위치에 넣어도 되는지.
///
/// 전사가 오래 걸리면 그사이 사용자가 다른 앱으로 넘어갈 수 있다. 그 앱에 텍스트를
/// 붙여넣거나 음성 명령의 Return을 보내면 엉뚱한 곳에 입력된다 — 키를 뗀 시점의 앱이
/// 여전히 앞에 있을 때만 넣고, 아니면 클립보드에만 담는다.
public enum LateResultPolicy {
    public enum Decision: Equatable, Sendable { case insert, copyOnly }

    public static func decide(frontmostAtKeyUp: Int32?, frontmostNow: Int32?) -> Decision {
        frontmostAtKeyUp == frontmostNow ? .insert : .copyOnly
    }
}
