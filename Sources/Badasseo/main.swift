import AppKit
import BadasseoAppKit
import Sparkle

// GitHub-release variant: Sparkle auto-updates, fed by appcast.xml on the
// GitHub "latest" release (SUFeedURL in Info.plist). Started eagerly so
// background update checks run on the interval Sparkle persists in user
// defaults. The Mac App Store variant (Sources/BadasseoAppStore) never sets
// badasseoCheckForUpdates — it stays nil there since that target doesn't
// link Sparkle at all (see Package.swift) — which hides the menu item.
// 메뉴바 전용(LSUIElement) 앱은 Sparkle의 모달 알림이 다른 앱 창 뒤에 뜰 수 있고,
// 그 모달이 앱 전체를 멈춰 세워 "먹통"처럼 보인다(업데이트 에러 알림으로 실측).
// 알림 직전에 앱을 활성화해 항상 앞에 보이게 한다.
final class UpdaterUIDelegate: NSObject, SPUStandardUserDriverDelegate {
    func standardUserDriverWillShowModalAlert() {
        NSApp.activate(ignoringOtherApps: true)
    }
}
let updaterUIDelegate = UpdaterUIDelegate()
let updaterController = SPUStandardUpdaterController(
    startingUpdater: true, updaterDelegate: nil, userDriverDelegate: updaterUIDelegate)
badasseoCheckForUpdates = { updaterController.updater.checkForUpdates() }

BadasseoRootApp.main()
