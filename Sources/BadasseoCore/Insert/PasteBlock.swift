import Foundation

/// 받아쓴 결과를 ⌘V로 자동 입력하지 못하는 이유. 이유마다 사용자가 할 일이 달라서 나눈다.
public enum PasteBlock: Equatable, Sendable {
    /// 손쉬운 사용 권한이 없다 — 사용자가 설정에서 켜야 한다.
    case noAccessibility
    /// 보안 입력 모드(암호 칸 입력용)가 켜져 있고, 지금 칸이 암호 칸이 아닌 텍스트 입력 칸이라고 확인되지
    /// 않았다. 권한과 무관하다.
    case secureInput

    /// 막는 것이 없으면 nil. 권한이 없으면 보안 입력과 관계없이 ⌘V를 보낼 수 없으므로 권한이 먼저다.
    ///
    /// 보안 입력은 시스템 전체에 걸려서, 켠 앱이 뒤에 있어도 켜진 것으로 읽힌다(2026-11-27·28 실사용:
    /// 뒤에 있던 Chrome 원격 데스크톱 때문에 모든 앱에서 붙여넣기가 멈췄다). 그 상태에서도 맨 앞
    /// 앱에 보낸 ⌘V는 들어가므로(11/27 실험), 지금 칸이 암호 칸이 아닌 텍스트 입력 칸이라고 확인될 때만
    /// (`.plainText`) 넣는다. 모르면 막는다 — 받아쓴 글이 암호 칸에 들어가 명령 키까지 눌리는 것보다
    /// 클립보드에 남는 편이 낫다.
    ///
    /// 누가 보안 입력을 켰는지는 보지 않는다. macOS가 알려 주는 값(`kCGSSessionSecureInputPID`)으로는 지금
    /// 누가 쥐고 있는지 알 수 없어서다(11/28 실험): `CGSessionCopyCurrentDictionary()`의 값은 늘 지금의 맨 앞
    /// 앱이었고, IOKit `IOConsoleUsers`의 값(`ioreg`와 같다)은 보안 입력이 켜지던 순간의 맨 앞 앱에 머물렀다
    /// (뒤의 프로그램이 켜도 그때 앞에 있던 앱이 기록됐다). 그래서 원격 데스크톱이 켜 둔 동안에는 맨 앞 앱의
    /// 암호 칸에 커서가 있어도 IOKit 값이 원격 데스크톱을 가리켰다 — 이 값을 믿고 넣으면 그 암호 칸에 글이
    /// 들어간다.
    public init?(trusted: Bool, secureInputOn: Bool, focusedField: FocusedField) {
        if !trusted {
            self = .noAccessibility
        } else if secureInputOn && focusedField != .plainText {
            self = .secureInput
        } else {
            return nil
        }
    }
}

/// 지금 키보드 입력이 가는 칸이 어떤 칸인지 — 손쉬운 사용 정보로 알아낸 것.
public enum FocusedField: Equatable, Sendable {
    /// 텍스트 입력 칸이고 암호 칸이 아니다.
    case plainText
    /// 암호 칸(하위 역할 AXSecureTextField).
    case password
    /// 알아내지 못했다 — 포커스된 칸을 못 찾았거나(칸 정보를 내주지 않는 앱, 응답 없는 앱), 텍스트 입력
    /// 칸이 아니거나, 하위 역할을 읽지 못했다.
    case unknown

    /// 손쉬운 사용 속성 하나를 읽은 결과.
    public enum Attribute: Equatable, Sendable {
        case value(String)
        /// 값이 없다(kAXErrorNoValue·kAXErrorAttributeUnsupported) — 보통 입력 칸의 하위 역할은 대개 이렇다.
        case absent
        /// 그 밖의 오류(응답 없음 등).
        case failed
    }

    /// 텍스트를 받는 역할. 이 밖의 역할(창·웹 영역 등)은 글이 어디로 갈지 알 수 없어 `unknown`이다.
    static let textEntryRoles: Set<String> = ["AXTextField", "AXTextArea", "AXComboBox"]

    public init(role: Attribute, subrole: Attribute) {
        guard case .value(let role) = role, Self.textEntryRoles.contains(role) else { self = .unknown; return }
        switch subrole {
        case .value("AXSecureTextField"): self = .password
        case .value, .absent: self = .plainText
        case .failed: self = .unknown
        }
    }
}
