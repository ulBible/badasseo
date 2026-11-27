import UserNotifications

/// 로컬 알림 — 권한은 최초 사용 시 provisional로 조용히 요청.
enum Notifier {
    static func copiedOnly() {
        post(body: L("⌘V로 붙여넣으세요. 자동 입력을 원하면 설정에서 손쉬운 사용을 켜주세요."))
    }

    /// 보안 입력 모드 때문에 자동 입력을 건너뛴 경우. 권한 문제가 아니므로 권한을 켜라고 하지 않는다
    /// (2026-11-27: 권한이 켜져 있는데도 권한 안내를 받고 설정에서 권한만 껐다 켰다). 앱 이름은 넣지
    /// 않는다 — 기록 값이 대개 실제로 켠 앱이 아니라 맨 앞 앱을 가리켜서, 이름을 대면 틀릴 수 있다.
    /// 대신 보안 입력을 오래 켜 두는 대표적인 경우를 든다.
    static func copiedSecureInput() {
        post(body: L("보안 입력(암호 입력용)이 켜져 있어 자동으로 넣지 못했어요. ⌘V로 붙여넣으세요. 암호 칸이 아닌데도 계속 이러면, 원격 데스크톱·암호 관리자처럼 보안 입력을 켜 두는 앱이나 터미널의 ‘보안 키보드 입력’ 설정을 확인해 보세요."))
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
