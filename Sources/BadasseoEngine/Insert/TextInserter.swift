import AppKit
import BadasseoCore
import ApplicationServices
import Carbon.HIToolbox

public enum InsertResult {
    case pasted
    /// 손쉬운 사용 권한이 없거나 키 이벤트를 만들지 못해 클립보드에만 담았다.
    case copiedOnly
    /// 보안 입력 모드가 켜져 있고 커서 칸이 보통 입력 칸이라고 확인하지 못해 클립보드에만 담았다
    /// (`PasteBlock.secureInput`).
    case copiedSecureInput
}

/// 커서 위치 삽입: 클립보드 백업 → ⌘V 합성 → 복원. 권한 없거나 합성 불가면 클립보드 복사만.
@MainActor
public enum TextInserter {
    public static var hasAccessibility: Bool { AXIsProcessTrusted() }

    /// ⌘V·명령 키 합성을 막는 것이 있는가(`PasteBlock`). 받아쓰기 한 번에 한 번만 부르고, 그 답을
    /// `insert`와 `press`에 넘긴다 — 따로 다시 판단하면 그사이 답이 바뀌어(손쉬운 사용 조회가 응답 없음으로
    /// 끝나는 등) 앱 전환 규칙을 건너뛰고 붙여넣거나, 글은 들어가고 명령 키만 빠질 수 있다.
    ///
    /// 보안 입력이 켜져 있을 때만 손쉬운 사용 정보를 더 읽는다. 평소 받아쓰기에는 비용을 더하지 않는다.
    /// 응답 없는 앱이 앞에 있으면 손쉬운 사용 조회 세 번에 최대 1.5초쯤 메인 스레드가 기다린다.
    /// 판단은 `PasteBlock`이 하고, 여기서는 사실(칸 종류, 칸이 터미널 앱에 있는가)만 모은다.
    public static func pasteBlock() -> PasteBlock? {
        guard hasAccessibility else { return .noAccessibility }
        guard IsSecureEventInputEnabled() else { return nil }
        let focus = focusedField()
        return PasteBlock(trusted: true, secureInputOn: true,
                          focusedField: focus?.field ?? .unknown,
                          focusedAppIsTerminal: TerminalApps.isTerminal(bundleID: focus?.bundleID))
    }

    /// 손쉬운 사용 조회가 응답 없는 앱에 오래 묶이지 않도록(기본값은 6초) 한 번만 줄여 둔다. 시스템 전체
    /// 요소에 거는 값이라 이 앱의 모든 손쉬운 사용 조회에 적용된다 — 이 앱은 다른 조회를 하지 않는다.
    private static let shortMessagingTimeout: Void = {
        AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), 0.5)
    }()

    /// 지금 키보드 입력이 가는 칸의 종류와, 그 칸이 속한 앱의 번들 ID. 시스템 전체 요소에 묻는다 — 앱을
    /// 앞으로 가져오지 않고 뜨는 창(암호 관리자의 빠른 입력 창 등)처럼 키보드 입력이 맨 앞 앱이 아닌 곳으로
    /// 갈 때도 실제로 입력이 가는 칸을 돌려준다. 앱도 맨 앞 앱이 아니라 이 칸의 PID로 찾는다. 칸을 찾지
    /// 못하면 nil, PID나 번들 ID를 모르면 번들 ID만 nil — 둘 다 `PasteBlock`이 막는 쪽으로 다룬다.
    /// 칸의 내용은 읽지 않는다.
    ///
    /// 진단용 명령줄 프로그램에서 이 조회를 재면 화면 서버(WindowServer)에 연결되기 전에는
    /// kAXErrorCannotComplete로 실패한다(2026-11-28 실측). 이 앱은 처음부터 연결돼 있어 해당하지 않는다.
    private static func focusedField() -> (field: FocusedField, bundleID: String?)? {
        _ = shortMessagingTimeout
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(AXUIElementCreateSystemWide(),
                                            kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused, CFGetTypeID(focused) == AXUIElementGetTypeID()
        else { return nil }
        let element = focused as! AXUIElement
        var pid: pid_t = 0
        let bundleID = AXUIElementGetPid(element, &pid) == .success
            ? NSRunningApplication(processIdentifier: pid)?.bundleIdentifier : nil
        return (FocusedField(role: read(element, kAXRoleAttribute), subrole: read(element, kAXSubroleAttribute)),
                bundleID)
    }

    private static func read(_ element: AXUIElement, _ attribute: String) -> FocusedField.Attribute {
        var value: CFTypeRef?
        switch AXUIElementCopyAttributeValue(element, attribute as CFString, &value) {
        case .success: return (value as? String).map { .value($0) } ?? .failed
        case .noValue, .attributeUnsupported: return .absent
        default: return .failed
        }
    }

    /// `block`은 `pasteBlock()`으로 이번 받아쓰기에 한 번 구한 답이다. 막는 것이 있으면 클립보드에만 담는다.
    @discardableResult
    public static func insert(_ text: String, block: PasteBlock?) -> InsertResult {
        let pb = NSPasteboard.general
        // 전체 타입 백업 — 문자열 아닌 클립보드 내용(이미지 등)도 손실 없이 복원
        let backupItems: [NSPasteboardItem] = (pb.pasteboardItems ?? []).map { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) { copy.setData(data, forType: type) }
            }
            return copy
        }
        copy(text)
        let ourChangeCount = pb.changeCount

        // 권한 없음 / 보안 입력(암호 칸일 수 있다 — 받아쓴 글을 암호 칸에 넣지 않는다) /
        // 이벤트 생성 실패 → 붙여넣기 시도하지 않고 클립보드에만 남김 (복원도 안 함 — 사용자가 ⌘V)
        switch block {
        case .noAccessibility: return .copiedOnly
        case .secureInput: return .copiedSecureInput
        case nil: break
        }
        let src = CGEventSource(stateID: .combinedSessionState)
        let vKey = CGKeyCode(9)  // kVK_ANSI_V
        guard let down = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: true),
              let up = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: false)
        else { return .copiedOnly }
        down.flags = .maskCommand
        up.flags = .maskCommand
        // .cgSessionEventTap, NOT .cghidEventTap: 샌드박스(MAS 빌드)는 HID 탭 포스팅을
        // 소리 없이 차단한다 — vClips가 실측으로 확인, 두 채널 모두 세션 탭으로 출시됨.
        down.post(tap: .cgSessionEventTap)
        up.post(tap: .cgSessionEventTap)

        // 복원: 대상 앱의 ⌘V 소비 시간을 여유 있게 두고(0.8s), 그 사이 사용자가 새로 복사했으면
        // (changeCount 변화) 건드리지 않는다. 완벽한 소비-시점 API는 macOS에 없음 — 업계 표준 타협.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            guard pb.changeCount == ourChangeCount else { return }
            pb.clearContents()
            if !backupItems.isEmpty { pb.writeObjects(backupItems) }
        }
        return .pasted
    }

    /// 붙여넣지 않고 클립보드에만 담는다 (이전 내용은 복원하지 않는다 — 사용자가 ⌘V로 꺼내 쓴다).
    public static func copy(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
        // 클립보드 매니저(vClips 등)가 전사 텍스트를 히스토리에 기록하지 않도록 — 업계 표준 마커
        pb.setString("", forType: NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"))
    }

    /// 음성 명령의 키 합성 — ⌘V 합성과 동일 채널(.cgSessionEventTap)·동일 가드.
    /// 붙여넣기 직후 호출된다 (타이밍은 호출자 책임 — AppState가 0.25초 지연). `block`은 붙여넣기 때 쓴
    /// 답을 그대로 넘긴다 — 다시 판단하면 글은 들어가고 키만 빠질 수 있다. 키를 보냈으면 true.
    @discardableResult
    public static func press(_ command: VoiceCommand, block: PasteBlock?) -> Bool {
        let key: CGKeyCode
        var flags: CGEventFlags = []
        switch command {
        case .enter: key = CGKeyCode(kVK_Return)
        case .newline: key = CGKeyCode(kVK_Return); flags = .maskShift
        case .tab: key = CGKeyCode(kVK_Tab)
        case .cancel: return false  // 키 동작 없는 명령
        }
        guard block == nil else { return false }
        let src = CGEventSource(stateID: .combinedSessionState)
        guard let down = CGEvent(keyboardEventSource: src, virtualKey: key, keyDown: true),
              let up = CGEvent(keyboardEventSource: src, virtualKey: key, keyDown: false)
        else { return false }
        down.flags = flags
        up.flags = flags
        down.post(tap: .cgSessionEventTap)
        up.post(tap: .cgSessionEventTap)
        return true
    }
}
