import AppKit
import ApplicationServices

public enum InsertResult { case pasted, copiedOnly }

/// 커서 위치 삽입: 클립보드 백업 → ⌘V 합성 → 복원. 권한 없으면 클립보드 복사만 (스펙 폴백).
public enum TextInserter {
    public static var hasAccessibility: Bool { AXIsProcessTrusted() }

    @discardableResult
    public static func insert(_ text: String) -> InsertResult {
        let pb = NSPasteboard.general
        let backup = pb.string(forType: .string)
        pb.clearContents()
        pb.setString(text, forType: .string)

        guard hasAccessibility else { return .copiedOnly }  // 백업 복원 안 함 — 사용자가 ⌘V 해야 하므로

        let src = CGEventSource(stateID: .combinedSessionState)
        let vKey = CGKeyCode(9)  // kVK_ANSI_V
        let down = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: true)
        let up = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)

        // 붙여넣기 완료 후 원래 클립보드 복원 (사용자 데이터 손실 없음 원칙)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            pb.clearContents()
            if let backup { pb.setString(backup, forType: .string) }
        }
        return .pasted
    }
}
