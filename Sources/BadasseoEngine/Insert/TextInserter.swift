import AppKit
import BadasseoCore
import ApplicationServices
import Carbon.HIToolbox

public enum InsertResult {
    case pasted
    /// 손쉬운 사용 권한이 없거나 키 이벤트를 만들지 못해 클립보드에만 담았다.
    case copiedOnly
    /// 보안 입력 모드가 켜져 있어 클립보드에만 담았다 — 맨 앞 앱이 켰거나 지금 칸이 암호 칸이거나
    /// 누가 켰는지 모를 때(`PasteBlock.secureInput`).
    case copiedSecureInput
}

/// 커서 위치 삽입: 클립보드 백업 → ⌘V 합성 → 복원. 권한 없거나 합성 불가면 클립보드 복사만.
@MainActor
public enum TextInserter {
    public static var hasAccessibility: Bool { AXIsProcessTrusted() }
    /// ⌘V·명령 키 합성으로 커서 위치에 넣을 수 있는 상태인가 — 권한이 있고, 보안 입력이 꺼져 있거나
    /// 뒤에 있는 앱이 켠 것이고 지금 칸이 암호 칸이 아닐 때(`PasteBlock`).
    public static var canAutoInsert: Bool { currentBlock == nil }

    private static var currentBlock: PasteBlock? {
        let secureOn = IsSecureEventInputEnabled()
        // 아래 두 조회는 보안 입력이 켜졌을 때만 한다(평소 받아쓰기에는 비용을 더하지 않는다).
        let heldInBackground = secureOn && secureInputHeldInBackground
        return PasteBlock(trusted: hasAccessibility, secureInputOn: secureOn,
                          heldInBackground: heldInBackground,
                          passwordFieldFocused: heldInBackground && passwordFieldFocused)
    }

    /// 보안 입력을 켠 앱이 지금 맨 앞 앱이 아닌 앱으로 기록돼 있는가. macOS 세션 정보의
    /// `kCGSSessionSecureInputPID`를 읽는다(`ioreg -l -w 0 | grep kCGSSessionSecureInputPID`와 같은 값).
    /// Apple 문서에 없는 키이고, 실제로 켠 앱이 아니라 맨 앞 앱이 기록될 때가 많다(2026-11-27 실험
    /// 6번 모두: 뒤의 앱이 켰는데 맨 앞 앱이 기록됨. 실사용 1번: 뒤에 있던 Chrome 원격 데스크톱이 제대로
    /// 기록됨). 그래서 "맨 앞 앱이 아닌 앱"으로 기록됐을 때만 뒤의 앱이 켰다고 보고, 키가 없거나 맨 앞
    /// 앱을 모르면 false(지금처럼 건너뛴다).
    private static var secureInputHeldInBackground: Bool {
        guard let session = CGSessionCopyCurrentDictionary() as? [String: Any],
              let pid = (session["kCGSSessionSecureInputPID"] as? NSNumber)?.int32Value,
              let front = NSWorkspace.shared.frontmostApplication?.processIdentifier
        else { return false }
        return pid != front
    }

    /// 지금 키보드 입력이 가는 칸이 암호 칸인가 — 손쉬운 사용 정보에서 그 칸의 하위 역할(subrole)이
    /// AXSecureTextField이면 암호 칸이다. 알아낼 수 없으면 false: Electron 앱(Slack 등)은 이 정보를
    /// 내주지 않는데(2026-11-27 실측: kAXErrorNoValue), 모름을 암호 칸으로 치면 그런 앱에서는 늘 건너뛰게
    /// 된다. 응답 없는 앱에 메인 스레드가 묶이지 않도록 0.5초만 기다린다(기본값은 6초).
    private static var passwordFieldFocused: Bool {
        let system = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(system, 0.5)
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let element = focused, CFGetTypeID(element) == AXUIElementGetTypeID()
        else { return false }
        var subrole: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element as! AXUIElement, kAXSubroleAttribute as CFString, &subrole) == .success
        else { return false }
        return (subrole as? String) == kAXSecureTextFieldSubrole
    }

    @discardableResult
    public static func insert(_ text: String) -> InsertResult {
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

        // 권한 없음 / 보안 입력(맨 앞 앱이 켰거나 암호 칸 — 받아쓴 글을 암호 칸에 넣지 않는다) /
        // 이벤트 생성 실패 → 붙여넣기 시도하지 않고 클립보드에만 남김 (복원도 안 함 — 사용자가 ⌘V)
        switch currentBlock {
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
    /// 붙여넣기 직후 호출된다 (타이밍은 호출자 책임 — AppState가 0.25초 지연).
    public static func press(_ command: VoiceCommand) {
        let key: CGKeyCode
        var flags: CGEventFlags = []
        switch command {
        case .enter: key = CGKeyCode(kVK_Return)
        case .newline: key = CGKeyCode(kVK_Return); flags = .maskShift
        case .tab: key = CGKeyCode(kVK_Tab)
        case .cancel: return  // 키 동작 없는 명령
        }
        guard canAutoInsert else { return }
        let src = CGEventSource(stateID: .combinedSessionState)
        guard let down = CGEvent(keyboardEventSource: src, virtualKey: key, keyDown: true),
              let up = CGEvent(keyboardEventSource: src, virtualKey: key, keyDown: false)
        else { return }
        down.flags = flags
        up.flags = flags
        down.post(tap: .cgSessionEventTap)
        up.post(tap: .cgSessionEventTap)
    }
}
