import AppKit

/// 우측 ⌘ 홀드로 푸시투토크를 구현하는 모니터.
///
/// 전역(global) + 로컬(local) `flagsChanged`/`keyDown` NSEvent 모니터 4개를 설치한다.
/// 전역 모니터만으로는 앱 자신이 키 이벤트의 대상일 때(예: 설정 창에 포커스가 있을 때)
/// 이벤트를 못 받으므로 로컬 모니터도 함께 둔다. 로컬 모니터는 관찰만 하고 이벤트를
/// 그대로 반환해 — 다른 키 처리(텍스트 입력 등)를 가로채지 않는다.
///
/// keyCode 54(우측 ⌘)만 매칭한다. 좌측 ⌘(keyCode 55)는 무시되므로 좌측 ⌘를 홀드해도
/// 녹음이 시작되지 않는다 — 좌측 ⌘는 macOS 전반의 조합 단축키(⌘C, ⌘Tab 등)에 쓰이기
/// 때문에, 우측 ⌘를 전용 푸시투토크 키로 비워두는 설계.
///
/// `onCancel` 가드: 홀드 중(`holding == true`) `keyDown`이 오면 — 즉 사용자가 우측 ⌘를
/// 다른 키와 조합했다면 — `canceled = true`로 표시해 두고, 홀드가 끝날 때 `onEnd` 대신
/// `onCancel`을 호출한다. 이는 "우측 ⌘를 조합 단축키로 쓰는 다른 사용자"를 보호하기
/// 위함이다: 우측 ⌘를 다른 앱/시스템 단축키에 매핑해 둔 사용자가 그 조합을 눌렀을 때,
/// 의도치 않게 녹음된 오디오가 전사·삽입되는 것을 막는다(녹음 자체는 폐기되고 조합은
/// 평소처럼 시스템/다른 앱으로 전달된다 — 로컬 모니터가 이벤트를 그대로 반환하므로).
@MainActor
public final class ModifierHoldMonitor {
    private let keyCode: UInt16
    private var holding = false
    private var canceled = false

    private var globalFlagsMonitor: Any?
    private var localFlagsMonitor: Any?
    private var globalKeyDownMonitor: Any?
    private var localKeyDownMonitor: Any?

    public var onBegin: (() -> Void)?
    public var onEnd: (() -> Void)?
    public var onCancel: (() -> Void)?

    /// - Parameter keyCode: 감시할 키코드. 기본값 54 = 우측 ⌘ (좌측은 55).
    public init(keyCode: UInt16 = 54) {
        self.keyCode = keyCode
    }

    public func start() {
        globalFlagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            Self.dispatchToMain { self?.handleFlagsChanged(event) }
        }
        localFlagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            Self.dispatchToMain { self?.handleFlagsChanged(event) }
            return event
        }
        globalKeyDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            Self.dispatchToMain { self?.handleKeyDown(event) }
        }
        localKeyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            Self.dispatchToMain { self?.handleKeyDown(event) }
            return event
        }
    }

    /// NSEvent 모니터 콜백은 AppKit 문서상 항상 메인 스레드에서 호출되지만, 그 가정이
    /// 틀렸을 때 `MainActor.assumeIsolated`는 즉시 크래시한다. 실제로 메인 스레드일 때는
    /// (거의 항상) 동기 실행해 기존 타이밍을 유지하고, 아닐 때만 메인 큐로 홉해
    /// 크래시 대신 안전하게 처리한다.
    private static func dispatchToMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread {
            MainActor.assumeIsolated { work() }
        } else {
            DispatchQueue.main.async { work() }
        }
    }

    public func stop() {
        [globalFlagsMonitor, localFlagsMonitor, globalKeyDownMonitor, localKeyDownMonitor]
            .compactMap { $0 }
            .forEach(NSEvent.removeMonitor)
        globalFlagsMonitor = nil
        localFlagsMonitor = nil
        globalKeyDownMonitor = nil
        localKeyDownMonitor = nil
    }

    /// 우측 ⌘의 물리적 디바이스 비트 (NX_DEVICERCMDKEYMASK, IOLLEvent.h).
    /// `NSEvent.ModifierFlags.command`는 좌/우 ⌘ 모두에 서는 OR 비트라서, 좌측 ⌘를
    /// 쥔 채로 우측 ⌘만 떼도 `.command`가 여전히 켜져 있어 release를 놓친다(→ 고착).
    /// 디바이스별 비트로 직접 검사해야 우측 ⌘ 하나의 물리 상태만 정확히 추적한다.
    /// 좌측 ⌘ 비트(NX_DEVICELCMDKEYMASK = 0x0008)와는 독립된 비트라 서로 간섭하지 않는다.
    private static let rightCommandDeviceMask: UInt = 0x0010

    private func handleFlagsChanged(_ event: NSEvent) {
        guard event.keyCode == keyCode else { return }
        let rightCmdDown = event.modifierFlags.rawValue & Self.rightCommandDeviceMask != 0
        if rightCmdDown, !holding {
            holding = true
            canceled = false
            onBegin?()
        } else if !rightCmdDown, holding {
            holding = false
            if canceled {
                onCancel?()
            } else {
                onEnd?()
            }
        }
    }

    private func handleKeyDown(_ event: NSEvent) {
        guard holding else { return }
        canceled = true
    }
}
