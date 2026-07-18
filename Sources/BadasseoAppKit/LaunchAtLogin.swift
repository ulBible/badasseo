import ServiceManagement

/// Wraps `SMAppService.mainApp` so the Settings UI can toggle "로그인 시 자동
/// 실행". Registration only works when running from an installed .app bundle
/// (e.g. /Applications/받아써.app); a bare `swift run` binary has no bundle
/// for launchd to point at, so `set(enabled:)` throws and the toggle reverts.
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func set(enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
