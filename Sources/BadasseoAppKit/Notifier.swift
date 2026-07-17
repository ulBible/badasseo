import UserNotifications

/// 로컬 알림 — 권한은 최초 사용 시 provisional로 조용히 요청.
enum Notifier {
    static func copiedOnly() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .provisional]) { _, _ in
            let content = UNMutableNotificationContent()
            content.title = "클립보드에 담았어요"
            content.body = "⌘V로 붙여넣으세요. 자동 입력을 원하면 설정에서 손쉬운 사용을 켜주세요."
            center.add(UNNotificationRequest(identifier: UUID().uuidString,
                                             content: content, trigger: nil))
        }
    }
}
