import Foundation

/// 받아쓴 결과를 ⌘V로 자동 입력하지 못하는 이유. 이유마다 사용자가 할 일이 달라서 나눈다.
public enum PasteBlock: Equatable, Sendable {
    /// 손쉬운 사용 권한이 없다 — 사용자가 설정에서 켜야 한다.
    case noAccessibility
    /// 보안 입력 모드(암호 칸 입력용)가 켜져 있고, 뒤에 있는 앱이 켰다고 확인되지 않았거나 지금 칸이
    /// 암호 칸이 아니라고 확인되지 않았다. 권한과 무관하다.
    case secureInput

    /// 막는 것이 없으면 nil. 권한이 없으면 보안 입력과 관계없이 ⌘V를 보낼 수 없으므로 권한이 먼저다.
    ///
    /// 보안 입력은 시스템 전체에 걸려서, 켠 앱이 뒤에 있어도 켜진 것으로 읽힌다(2026-11-27 실사용:
    /// 뒤에 있던 Chrome 원격 데스크톱 때문에 모든 앱에서 붙여넣기가 멈췄다). 그 상태에서도 맨 앞
    /// 앱에 보낸 ⌘V는 들어가므로(같은 날 실험), 켠 앱이 뒤에 있다고 확인되고(`heldInBackground`)
    /// 지금 칸이 암호 칸이 아닌 텍스트 입력 칸이라고 확인될 때만(`.plainText`) 넣는다. 모르면 막는다 —
    /// 받아쓴 글이 암호 칸에 들어가 명령 키까지 눌리는 것보다 클립보드에 남는 편이 낫다.
    public init?(trusted: Bool, secureInputOn: Bool, heldInBackground: Bool, focusedField: FocusedField) {
        if !trusted {
            self = .noAccessibility
        } else if secureInputOn && !(heldInBackground && focusedField == .plainText) {
            self = .secureInput
        } else {
            return nil
        }
    }

    /// 보안 입력을 켠 앱이 뒤에 있다고 볼 수 있는가. 기록된 PID(`kCGSSessionSecureInputPID`)가 맨 앞 앱과도,
    /// 키보드 입력을 받는 칸의 앱과도 다를 때만 그렇다. 앱을 앞으로 가져오지 않고 뜨는 창(암호 관리자의
    /// 빠른 입력 창 등)은 맨 앞 앱이 아니어서, 맨 앞 앱만 보면 그 창이 켠 보안 입력을 뒤의 것으로 오판한다.
    /// 셋 중 하나라도 모르면 false.
    ///
    /// 이 기록 값은 대개 맨 앞 앱을 따라간다(2026-11-27 실험: 창 없는 프로그램과 뒤에 뜬 GUI 앱이
    /// 켰을 때 모두 맨 앞 앱이 기록됐고, 앞 앱을 바꾸기만 해도 따라 바뀌었다). 맨 앞 앱이 아닌 앱이
    /// 기록되는 것은 실사용의 Chrome 원격 데스크톱 같은 경우뿐이었다.
    public static func heldInBackground(recordedPID: Int32?, frontmostPID: Int32?, focusedPID: Int32?) -> Bool {
        guard let recordedPID, let frontmostPID, let focusedPID else { return false }
        return recordedPID != frontmostPID && recordedPID != focusedPID
    }
}

/// 지금 키보드 입력이 가는 칸이 어떤 칸인지 — 손쉬운 사용 정보로 알아낸 것.
public enum FocusedField: Equatable, Sendable {
    /// 텍스트 입력 칸이고 암호 칸이 아니다.
    case plainText
    /// 암호 칸(하위 역할 AXSecureTextField).
    case password
    /// 알아내지 못했다 — 포커스된 칸을 못 찾았거나(Electron 앱 다수, 응답 없는 앱), 텍스트 입력 칸이
    /// 아니거나, 하위 역할을 읽지 못했다.
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
