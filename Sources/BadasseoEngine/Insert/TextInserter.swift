import AppKit
import BadasseoCore
import ApplicationServices
import Carbon.HIToolbox

public enum InsertResult { case pasted, copiedOnly }

/// 커서 위치 삽입: 클립보드 백업 → ⌘V 합성 → 복원. 권한 없거나 합성 불가면 클립보드 복사만.
@MainActor
public enum TextInserter {
    public static var hasAccessibility: Bool { AXIsProcessTrusted() }

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
        pb.clearContents()
        pb.setString(text, forType: .string)
        // 클립보드 매니저(vClips 등)가 전사 텍스트를 히스토리에 기록하지 않도록 — 업계 표준 마커
        pb.setString("", forType: NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"))
        let ourChangeCount = pb.changeCount

        // 권한 없음 / 보안 입력 활성(암호 필드 — 합성 이벤트가 시스템에서 무시됨) /
        // 이벤트 생성 실패 → 붙여넣기 시도하지 않고 클립보드에만 남김 (복원도 안 함 — 사용자가 ⌘V)
        guard hasAccessibility, !IsSecureEventInputEnabled() else { return .copiedOnly }
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
        guard hasAccessibility, !IsSecureEventInputEnabled() else { return }
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
