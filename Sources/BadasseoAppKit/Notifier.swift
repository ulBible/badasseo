import UserNotifications

/// 로컬 알림 — 권한은 최초 사용 시 provisional로 조용히 요청.
enum Notifier {
    static func copiedOnly() {
        post(body: L("⌘V로 붙여넣으세요. 자동 입력을 원하면 설정에서 손쉬운 사용을 켜주세요."))
    }

    /// 전사가 끝났을 때 다른 앱이 앞에 있어 자동 입력을 건너뛴 경우.
    static func copiedAfterAppSwitch() {
        post(body: L("받아쓰는 사이 다른 앱으로 넘어가서 자동 입력하지 않았어요. ⌘V로 붙여넣으세요."))
    }

    private static func post(body: String) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .provisional]) { _, _ in
            let content = UNMutableNotificationContent()
            content.title = L("클립보드에 담았어요")
            content.body = body
            center.add(UNNotificationRequest(identifier: UUID().uuidString,
                                             content: content, trigger: nil))
        }
    }
}
