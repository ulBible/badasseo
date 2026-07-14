import AppKit
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
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)

        // 복원: 대상 앱의 ⌘V 소비 시간을 여유 있게 두고(0.8s), 그 사이 사용자가 새로 복사했으면
        // (changeCount 변화) 건드리지 않는다. 완벽한 소비-시점 API는 macOS에 없음 — 업계 표준 타협.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            guard pb.changeCount == ourChangeCount else { return }
            pb.clearContents()
            if !backupItems.isEmpty { pb.writeObjects(backupItems) }
        }
        return .pasted
    }
}
