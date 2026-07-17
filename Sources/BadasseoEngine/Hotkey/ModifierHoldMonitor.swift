import AppKit
import ApplicationServices
import BadasseoCore

/// 선택된 수식키(`HoldKey`) 홀드로 푸시투토크를 구현하는 모니터.
///
/// 로컬(local) + 전역(global) `flagsChanged`/`keyDown` NSEvent 모니터를 각각 둔다.
/// 로컬 모니터는 권한 없이 동작하며(자기 앱이 포커스일 때만 이벤트 수신) `start()`에서
/// 즉시 설치된다 — 온보딩 튜토리얼이 이걸로 커버된다. 전역 모니터는 macOS 손쉬운 사용
/// (Accessibility) 권한이 있어야 이벤트가 오는데, 그 모니터를 "설치"하는 행위 자체가
/// macOS로 하여금 권한 프롬프트/설정 유도를 띄우게 만든다 — 그래서 사용자가 실제로
/// 권한을 부여하기 전에는(`AXIsProcessTrusted()`) 설치하지 않는다
/// (`installGlobalMonitorsIfNeeded()`). 로컬 모니터는 관찰만 하고 이벤트를 그대로
/// 반환해 — 다른 키 처리(텍스트 입력 등)를 가로채지 않는다.
///
/// 이벤트마다 `HoldKey.current`를 읽어 판정한다 — 설정 변경 시 모니터 재시작이
/// 필요 없다(기존 hotkeyMode per-event 가드와 같은 패턴). 기본값은 우측 ⌘
/// (keyCode 54); 좌측 ⌘(keyCode 55)는 무시되므로 좌측 ⌘를 홀드해도 녹음이
/// 시작되지 않는다 — 좌측 ⌘는 macOS 전반의 조합 단축키(⌘C, ⌘Tab 등)에 쓰이기
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
    private var holding = false
    private var canceled = false
    /// 홀드 시작 시점의 키를 캡처해 둔다 — 홀드 중 설정이 바뀌는 극단 케이스에도
    /// 릴리즈 판정은 시작 시점 키 기준으로 일관되게 이뤄진다.
    private var activeKey: HoldKey?

    private var globalFlagsMonitor: Any?
    private var localFlagsMonitor: Any?
    private var globalKeyDownMonitor: Any?
    private var localKeyDownMonitor: Any?

    public var onBegin: (() -> Void)?
    public var onEnd: (() -> Void)?
    public var onCancel: (() -> Void)?

    public init() {}

    /// 로컬 모니터만 설치 — 권한이 필요 없고, macOS의 권한 프롬프트/설정 유도를
    /// 트리거하지 않는다. 앱 실행 시 무조건 호출해도 안전(옵트인 원칙 유지).
    public func start() {
        localFlagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            Self.dispatchToMain { self?.handleFlagsChanged(event) }
            return event
        }
        localKeyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            Self.dispatchToMain { self?.handleKeyDown(event) }
            return event
        }
    }

    /// 손쉬운 사용 권한이 이미 부여된 경우에만 전역 모니터 2개를 설치한다 —
    /// 그 전에는 호출해도 아무 일도 안 일어나(권한 프롬프트 없음), 사용자가
    /// 온보딩에서 명시적으로 권한을 켠 뒤(또는 이미 켜져 있는 채 앱을 실행한 뒤)에만
    /// 전역 감시가 붙는다. 이미 설치돼 있으면 중복 설치하지 않는다(no-op 가드).
    public func installGlobalMonitorsIfNeeded() {
        guard AXIsProcessTrusted() else { return }
        guard globalFlagsMonitor == nil, globalKeyDownMonitor == nil else { return }
        globalFlagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            Self.dispatchToMain { self?.handleFlagsChanged(event) }
        }
        globalKeyDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            Self.dispatchToMain { self?.handleKeyDown(event) }
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

    /// `NSEvent.ModifierFlags.command`처럼 좌/우가 OR로 묶인 상위 플래그만으로는
    /// 좌측을 쥔 채 우측만 떼는 경우 release를 놓친다(→ 고착). 디바이스별 비트
    /// (IOLLEvent.h, `HoldKey.deviceMask`)로 직접 검사해야 선택된 키 하나의
    /// 물리 상태만 정확히 추적한다. fn은 디바이스 비트가 없어 `.function` 플래그로 판정.
    private func handleFlagsChanged(_ event: NSEvent) {
        let key = activeKey ?? HoldKey.current
        guard event.keyCode == key.keyCode else { return }
        let pressed: Bool
        if let mask = key.deviceMask { pressed = event.modifierFlags.rawValue & mask != 0 }
        else { pressed = event.modifierFlags.contains(.function) }   // fn

        if pressed, !holding {
            holding = true
            canceled = false
            activeKey = key
            onBegin?()
        } else if !pressed, holding {
            holding = false
            activeKey = nil
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
