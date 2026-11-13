import SwiftUI
import ApplicationServices
import os
import KeyboardShortcuts
import BadasseoCore
import BadasseoEngine

extension KeyboardShortcuts.Name {
    static let pushToTalk = Self("pushToTalk", default: .init(.space, modifiers: [.option]))
}

@MainActor
final class AppState: ObservableObject {
    enum Status { case idle, recording, processing, noSpeech, error(String) }
    @Published var status: Status = .idle {
        didSet {
            // 변환 중 메뉴바 타이핑 애니메이션 프레임 구동. TimelineView를 MenuBarExtra
            // 라벨에 넣으면 requestUpdate가 자기 자신을 무한 재귀해 메인 스레드가 100%로
            // 마비된다(실측 — 전사 완료 콜백까지 굶겨 앱 먹통). 타이머로 틱당 1회만 갱신.
            if case .processing = status {
                guard frameTimer == nil else { return }
                frameTimer = Timer.scheduledTimer(withTimeInterval: 0.18, repeats: true) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        self.processingFrame = (self.processingFrame + 1) % 4
                    }
                }
            } else {
                frameTimer?.invalidate()
                frameTimer = nil
                processingFrame = 0
            }
        }
    }
    /// 변환 중 애니메이션의 현재 프레임(0~3줄).
    @Published var processingFrame = 0
    private var frameTimer: Timer?
    @Published var lastResult: String = ""

    private let support = FileManager.default.urls(for: .applicationSupportDirectory,
                                                   in: .userDomainMask)[0]
        .appendingPathComponent("Badasseo")
    private lazy var dictionary = UserDictionary.standard
    private(set) lazy var history = HistoryStore.standard
    private let capture = AudioCapture()
    /// 엔진의 유일한 소유자. 로드·전사·해제가 한 직렬 큐에서 차례로 일어나므로 엔진은 언제나
    /// 하나뿐이다 — 로드가 끝나기 전에 받아쓰기를 다시 시도해도 새로 만들지 않는다
    /// (1.6GB 엔진이 여러 개 생기면 GPU 메모리가 고갈된다. 실측: 9개 = 16GB, 전사 영구 멈춤).
    private lazy var engineHost = EngineHost<WhisperEngine> { [modelPath = self.modelPath] in
        try WhisperEngine(modelPath: modelPath)
    }
    /// 키를 누른 뒤 엔진 준비를 시작하기까지의 대기 — 키를 떼거나 취소하면 무효가 된다.
    private var prepareTask: Task<Void, Never>?
    private var idleCheckTimer: Timer?
    private var recordingStartedAt: Date?
    private var lastDictationEndedAt: Date?
    private let modifierHoldMonitor = ModifierHoldMonitor()
    private var noSpeechGeneration = 0

    /// 손쉬운 사용 권한 상태 — 메뉴 안내 문구가 권한 변화에 맞춰 다시 그려지도록 게시한다.
    @Published private(set) var axTrusted = AXIsProcessTrusted()
    private var accessibilityListObserver: DistributedObserver?
    private var accessibilityRecheck: Task<Void, Never>?
    private static let log = Logger(subsystem: "app.badasseo", category: "accessibility")
    /// 받아쓰기마다 걸린 시간을 한 줄씩 남긴다 — 숫자만, 말한 내용은 절대 남기지 않는다.
    /// 보기: `log show --last 1h --predicate 'subsystem == "app.badasseo" && category == "latency"'`
    private static let latencyLog = Logger(subsystem: "app.badasseo", category: "latency")

    /// 현재 녹음 세션을 시작시킨 경로("rightCommand"/"custom"). begin 시점에만 모드를
    /// 확인해 세팅하고, end/cancel은 모드 재확인 대신 이 값으로 자기 세션인지만 본다 —
    /// 그래야 녹음 중 설정에서 모드를 바꿔도 시작한 경로가 끝까지 책임지고 정리한다
    /// (모드를 양쪽에서 가드하면, 전환 후 end 가드가 막혀 `.recording`에 고착된다).
    private var activeHotkeySource: String?

    /// 두 단축키 경로(우측 ⌘ 홀드 / 사용자 지정 조합) 모두 항상 연결돼 있고,
    /// begin 시점에 이 값을 확인해 실행 여부를 가른다 — 설정 변경 시 재구성이 필요 없다.
    static var hotkeyMode: String {
        UserDefaults.standard.string(forKey: "hotkeyMode") ?? "rightCommand"
    }

    var modelPath: String {
        support.appendingPathComponent("models/ggml-large-v3-turbo.bin").path
    }

    init() {
        KeyboardShortcuts.onKeyDown(for: .pushToTalk) { [weak self] in
            guard Self.hotkeyMode == "custom", self?.activeHotkeySource == nil else { return }
            self?.activeHotkeySource = "custom"
            self?.beginRecording()
        }
        KeyboardShortcuts.onKeyUp(for: .pushToTalk) { [weak self] in
            guard self?.activeHotkeySource == "custom" else { return }
            self?.endRecording()
        }
        modifierHoldMonitor.onBegin = { [weak self] in
            guard Self.hotkeyMode == "rightCommand", self?.activeHotkeySource == nil else { return }
            self?.activeHotkeySource = "rightCommand"
            self?.beginRecording()
        }
        modifierHoldMonitor.onEnd = { [weak self] in
            guard self?.activeHotkeySource == "rightCommand" else { return }
            self?.endRecording()
        }
        modifierHoldMonitor.onCancel = { [weak self] in
            guard self?.activeHotkeySource == "rightCommand" else { return }
            self?.cancelRecording()
        }
        modifierHoldMonitor.start()
        // 이미 손쉬운 사용 권한이 있으면(과거 부여했거나 tccutil 리셋 안 된 경우) 즉시
        // 전역 모니터까지 가동 — 권한이 없으면 여기서는 아무 일도 안 일어난다(옵트인).
        modifierHoldMonitor.installGlobalMonitorsIfNeeded()
        // 온보딩 허용 버튼 폴러(HotkeyStep)가 권한 획득을 감지한 경로.
        NotificationCenter.default.addObserver(forName: .badasseoAXGranted, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refreshAccessibility() }
        }
        // 받아써 창으로 돌아온 경우.
        NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refreshAccessibility() }
        }
        // 시스템 설정에서 직접 켜고 받아써 창은 열지 않은 경우 — 메뉴바 앱은 거의 항상
        // 비활성이라 위 두 경로가 오지 않는다. macOS는 손쉬운 사용 목록이 바뀔 때 이
        // 분산 알림을 보낸다(권한 없이 구독 가능).
        accessibilityListObserver = DistributedObserver(name: "com.apple.accessibility.api") { [weak self] in
            Task { @MainActor in self?.recheckAccessibilitySoon() }
        }
        // custom 모드가 아니면 Carbon 핫키 등록을 비활성 — 등록만으로도 ⌥Space가
        // 시스템 전역에서 소비되어(Alfred 등과 충돌) "무간섭" 원칙을 깬다.
        // 모드 전환 시 GeneralTab이 enable/disable을 토글한다.
        if Self.hotkeyMode != "custom" { KeyboardShortcuts.disable(.pushToTalk) }
    }

    /// 손쉬운 사용 권한을 다시 읽어 전역 모니터와 메뉴·설정 안내에 반영한다 — 켜져 있으면 전역
    /// 모니터를 (없을 때) 붙이고, 꺼졌으면 뗀다. 떼는 이유: 입력 모니터링 권한이 따로 있으면
    /// 손쉬운 사용 없이도 전역 키 입력이 들어오는데(실측), 그러면 "다른 앱에서는 동작하지
    /// 않아요" 안내와 실제 동작이 어긋나고 붙여넣기도 안 돼 결과가 사라진 것처럼 보인다.
    private func refreshAccessibility() {
        let trusted = AXIsProcessTrusted()
        if trusted != axTrusted {
            Self.log.notice("accessibility trusted changed: \(trusted, privacy: .public)")
            axTrusted = trusted
        }
        if trusted {
            modifierHoldMonitor.installGlobalMonitorsIfNeeded()
        } else {
            modifierHoldMonitor.removeGlobalMonitors()
        }
    }

    /// 알림 직후가 아니라 1초 뒤에 한 번 읽는다. AXIsProcessTrusted()는 결과를 프로세스 안에
    /// 캐시하고, 이 분산 알림이 오면 캐시를 버린 뒤 다음 호출 때 한 번만 tccd에 다시 묻는다
    /// (실측: 14초간 14번 호출에 tccd 조회 2번). 그런데 시스템 설정은 권한을 저장하기 5~17ms
    /// 전에 알림을 보내서, 곧바로 읽으면 옛 값이 캐시에 굳어 다음 변경 때까지 정반대 상태를
    /// 믿게 된다(실측: 켜면 꺼짐, 끄면 켜짐으로 한 박자씩 밀림). 연속 변경은 마지막 것만 반영.
    private func recheckAccessibilitySoon() {
        Self.log.notice("accessibility list changed — rechecking in 1s")
        accessibilityRecheck?.cancel()
        accessibilityRecheck = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard let self, !Task.isCancelled else { return }
            self.refreshAccessibility()
        }
    }

    private func beginRecording() {
        // .error에서도 시작 허용 — 레코딩 재시도가 곧 에러 해제. (에러 문구는 다음 시도까지 메뉴에 유지)
        switch status { case .idle, .error, .noSpeech: break; default: return }
        // 모델이 준비되기 전에는 녹음 자체를 시작하지 않는다 (마이크·효과음 비활성) —
        // 다운로드 중 단축키를 눌러도 마이크가 켜지거나 시작음이 나지 않아야 한다.
        guard let size = try? FileManager.default.attributesOfItem(atPath: modelPath)[.size] as? Int64,
              size == ModelInfo.byteSize else {
            status = .error(L("모델 다운로드가 끝나면 사용할 수 있어요"))
            return
        }
        do {
            try capture.start()
            status = .recording
            // 시작음은 의도적으로 즉시 재생 — "녹음이 시작됐다"는 피드백이 목적이라 지연 불가.
            // 조합 취소(cancelRecording) 시 종료음만 억제됨: 시작음이 이미 난 것은 수용된 트레이드오프
            // (opt-in 설정 + 취소는 mic 데이터도 폐기되므로 내용 유출 없음).
            SoundPlayer.shared.playStart()
            recordingStartedAt = Date()
            schedulePrepare()
        } catch { status = .error(L("마이크 시작 실패")) }
    }

    /// 말하는 동안 엔진을 준비해 둔다 — 엔진이 내려가 있으면(첫 받아쓰기, 또는 메모리 압박으로
    /// 해제된 뒤) 키를 뗀 다음이 아니라 지금 로드를 시작해 그 시간을 발화 시간에 묻는다.
    /// 0.3초 기다렸다 시작하는 이유: 스친 입력(0.5초 미만은 어차피 버린다)이나 우측 ⌘ 조합
    /// 단축키에 1.6GB 로드를 헛돌리지 않기 위해서다.
    private func schedulePrepare() {
        prepareTask?.cancel()
        prepareTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard let self, !Task.isCancelled, case .recording = self.status else { return }
            if self.activeHotkeySource == "rightCommand", self.modifierHoldMonitor.isComboInProgress { return }
            self.engineHost.prepare()
            self.startIdleChecks()
        }
    }

    /// 엔진이 올라와 있는 동안 주기적으로, 메모리 압박 속에 쉬고 있으면 내려놓는다
    /// (이유와 기준은 `EngineIdlePolicy`). 내려간 뒤에는 타이머도 멈춘다.
    private func startIdleChecks() {
        guard idleCheckTimer == nil else { return }
        let timer = Timer.scheduledTimer(withTimeInterval: EngineIdlePolicy.checkInterval,
                                         repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in await self?.unloadEngineIfIdle() }
        }
        timer.tolerance = EngineIdlePolicy.checkInterval / 3
        idleCheckTimer = timer
    }

    private func stopIdleChecks() {
        idleCheckTimer?.invalidate()
        idleCheckTimer = nil
    }

    private func unloadEngineIfIdle() async {
        switch status { case .recording, .processing: return; default: break }
        guard EngineIdlePolicy.isUnderPressure(level: MemoryPressure.currentLevel()) else { return }
        switch await engineHost.unloadIfIdle(minIdle: EngineIdlePolicy.minIdleSeconds) {
        case .unloaded:
            Self.latencyLog.notice("engine unloaded: idle under memory pressure")
            stopIdleChecks()
        case .notLoaded:
            stopIdleChecks()
        case .stillInUse:
            break
        }
    }

    /// 홀드 중 다른 키가 눌려 조합 단축키로 판정된 경우 — 전사하지 않고 녹음을 폐기.
    private func cancelRecording() {
        activeHotkeySource = nil
        prepareTask?.cancel()
        guard case .recording = status else { return }
        _ = capture.stop()
        status = .idle
    }

    private func showNoSpeech() {
        noSpeechGeneration += 1
        let gen = noSpeechGeneration
        status = .noSpeech
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            if case .noSpeech = self.status, gen == self.noSpeechGeneration { self.status = .idle }
        }
    }

    private func endRecording() {
        activeHotkeySource = nil
        prepareTask?.cancel()
        guard case .recording = status else { return }
        let samples = capture.stop()
        status = .processing
        guard samples.count > 8000 else { status = .idle; return }  // <0.5초 = 무시 (무반응 — 종료음도 없음)
        guard !SpeechGate.isSilence(samples: samples) else { showNoSpeech(); return }  // 무음 — 전사 생략
        SoundPlayer.shared.playStop()
        let dict = dictionary.load()
        let terms = dictionary.promptTerms()
        // 주의: 명령 트리거 단어를 initial prompt에 넣지 말 것 — 넣었더니 불명확한
        // 발화 구간에 트리거 단어가 쉼표까지 딸린 채 환각 삽입됐다("… 뉴라인, 또 …",
        // 2026-07-20 실사용 보고). 명령어 오인식("줄바꿈"→"출바꿈")은 그 표기를
        // 동의어로 등록해 해결한다 — 본문 오염 없는 유일한 경로.
        // 엔진 작업은 전부 engineHost의 직렬 큐에서 한다 — 메인 스레드를 막지 않고, 말하는
        // 동안 시작해 둔 로드(schedulePrepare)가 있으면 그 뒤에 줄을 서서 같은 엔진을 쓴다.
        let host = engineHost
        let modelPath = self.modelPath
        let keyUp = Date()
        let heldSeconds = recordingStartedAt.map { keyUp.timeIntervalSince($0) } ?? 0
        let idleSeconds = lastDictationEndedAt.map { keyUp.timeIntervalSince($0) }
        let usageAtKeyUp = ProcessUsage.current()
        let pressureLevel = MemoryPressure.currentLevel()
        // 전사가 끝났을 때도 이 앱이 앞에 있어야 자동 입력한다 (LateResultPolicy).
        let frontmostAtKeyUp = NSWorkspace.shared.frontmostApplication?.processIdentifier
        startIdleChecks()
        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                let (raw, timing) = try await host.run { engine, info in
                    let started = Date()
                    let text = try engine.transcribe(samples: samples, promptTerms: terms)
                    return (text, EngineTiming(info: info,
                                               waitSeconds: started.timeIntervalSince(keyUp),
                                               whisperSeconds: Date().timeIntervalSince(started)))
                }
                let refined = Refiner.refine(raw, dictionary: dict)
                // 음성 명령: 정제 후 마지막 단어를 검사. 토글 OFF면 파서를 타지 않아
                // 키워드가 일반 텍스트로 그대로 삽입된다.
                let (finalText, command) = VoiceCommandSettings.isEnabled()
                    ? VoiceCommandParser.parse(refined, triggers: VoiceCommandSettings.triggers())
                    : (refined, nil)
                await MainActor.run {
                    guard let self else { return }
                    // 온보딩 창이 떠 있으면 자동 삽입(⌘V 합성)을 건너뛴다 — 튜토리얼은
                    // 아래 알림 경로로만 입력칸에 표시하므로, ⌘V까지 하면 이중 입력이 된다.
                    // key window일 때만 건너뛴다(visible이 아님) — 온보딩 창을 뒤로 둔 채
                    // 다른 앱에 받아쓰면 정상 삽입돼야 한다(전사 유실 방지).
                    let onboardingActive = NSApp.windows.contains {
                        $0.identifier?.rawValue == "onboarding" && $0.isKeyWindow
                    }
                    // 전사가 오래 걸린 사이 다른 앱으로 넘어갔으면 그 앱에 붙여넣거나 명령 키를
                    // 보내지 않는다 — 클립보드에만 담고 알린다.
                    let sameAppInFront = {
                        LateResultPolicy.decide(
                            frontmostAtKeyUp: frontmostAtKeyUp,
                            frontmostNow: NSWorkspace.shared.frontmostApplication?.processIdentifier) == .insert
                    }
                    let outcome: String
                    if command == .cancel {
                        // 폐기 — 삽입·히스토리·브로드캐스트 없음. 유일한 피드백은
                        // 확인음(화면 신호가 없는 경로라 소리가 폐기 사실을 알린다).
                        SoundPlayer.shared.playCommand()
                        self.status = .idle
                        outcome = "discarded"
                    } else if finalText.isEmpty, let command {
                        // 명령 단독 발화("엔터") — 붙여넣기 없이 키만
                        if !onboardingActive, sameAppInFront() {
                            TextInserter.press(command)
                            SoundPlayer.shared.playCommand()
                            outcome = "command"
                        } else {
                            outcome = "command-skipped"
                        }
                        self.status = .idle
                    } else if finalText.isEmpty || SpeechGate.isJunk(finalText) {
                        self.showNoSpeech()  // 무음·잡음·환각 토큰 — 삽입하지 않음 (스펙)
                        outcome = "no-speech"
                    } else {
                        if onboardingActive {
                            outcome = "onboarding"
                        } else if !sameAppInFront() {
                            TextInserter.copy(finalText)
                            Notifier.copiedAfterAppSwitch()
                            outcome = "copied-app-switched"
                        } else {
                            switch TextInserter.insert(finalText) {
                            case .copiedOnly:
                                Notifier.copiedOnly()  // 키 합성도 불가한 상태 — 명령 생략
                                outcome = "copied"
                            case .pasted:
                                outcome = "pasted"
                                if let command {
                                    // 대상 앱이 ⌘V를 소화한 뒤 키가 도착해야 한다 (스펙: 0.25초).
                                    // 그 사이 새 녹음이 시작됐거나(상태 변화) 앱이 바뀌었으면 키를
                                    // 쏘지 않는다 — 지연된 Return이 다른 맥락에 꽂히는 사고 방지.
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                                        guard let self, case .idle = self.status, sameAppInFront() else { return }
                                        TextInserter.press(command)
                                        SoundPlayer.shared.playCommand()
                                    }
                                }
                            }
                        }
                        self.history.append(finalText)
                        self.lastResult = finalText
                        self.status = .idle
                        // 붙여넣기 경로와 무관하게 전사 결과를 브로드캐스트 —
                        // 온보딩 튜토리얼이 합성 ⌘V 성공 여부에 기대지 않고 직접 표시.
                        NotificationCenter.default.post(name: .badasseoDidTranscribe, object: finalText)
                    }
                    self.lastDictationEndedAt = Date()
                    self.logLatency(audioSeconds: Double(samples.count) / 16000, heldSeconds: heldSeconds,
                                    idleSeconds: idleSeconds, pressureLevel: pressureLevel, timing: timing,
                                    keyUp: keyUp, usageAtKeyUp: usageAtKeyUp, outcome: outcome)
                }
            } catch WhisperError.modelLoadFailed {
                await MainActor.run { self?.status = .error(L("모델 없음: \(modelPath)")) }
            } catch {
                await MainActor.run { self?.status = .error(L("전사 실패 — 다시 시도해 주세요")) }
            }
        }
    }

    private func logLatency(audioSeconds: Double, heldSeconds: Double, idleSeconds: Double?,
                            pressureLevel: Int32, timing: EngineTiming, keyUp: Date,
                            usageAtKeyUp: ProcessUsage?, outcome: String) {
        let total = Date().timeIntervalSince(keyUp)
        let used = ProcessUsage.current().flatMap { now in usageAtKeyUp.map { now.delta(since: $0) } }
        // 엔진이 원래 올라와 있었는지, 이번에 로드됐다면 말하는 동안이었는지 키를 뗀 뒤였는지.
        let engineState: String
        if timing.info.loadedNow {
            engineState = "loaded-after-keyup"
        } else if timing.info.secondsSinceLoad <= heldSeconds + timing.waitSeconds {
            engineState = "loaded-while-speaking"
        } else {
            engineState = "resident"
        }
        let ms = { (seconds: Double) in Int((seconds * 1000).rounded()) }
        // total: 키를 뗀 뒤 결과 처리까지. wait: 그중 엔진이 일을 시작하기까지(로드 포함).
        // disk: 그동안 디스크에서 읽은 양 — 크면 모델 로드이거나 스왑에서 되읽은 것이다.
        Self.latencyLog.notice("dictation audio=\(audioSeconds, format: .fixed(precision: 1))s total=\(ms(total))ms wait=\(ms(timing.waitSeconds))ms whisper=\(ms(timing.whisperSeconds))ms engine=\(engineState, privacy: .public) idle=\(idleSeconds.map { Int($0) } ?? -1)s pressure=\(pressureLevel) disk=\(Int(used?.diskMegabytesRead ?? -1))MB cpu=\(used.map { ms($0.cpuSeconds) } ?? -1)ms outcome=\(outcome, privacy: .public)")
    }
}

/// `EngineHost.run` 한 번의 시간 기록 — 지연 로그용.
private struct EngineTiming: Sendable {
    let info: EngineRunInfo
    /// 키를 뗀 뒤 엔진이 전사를 시작하기까지 (앞선 로드를 기다린 시간 포함).
    let waitSeconds: TimeInterval
    /// whisper_full 한 번.
    let whisperSeconds: TimeInterval
}

/// 분산 알림을 "즉시 전달"로 구독하는 얇은 래퍼 — 블록 기반 API에는 suspensionBehavior
/// 인자가 없는데, 비활성 앱에는 전달이 보류될 수 있어 메뉴바 앱에선 알림이 제때 오지 않는다.
private final class DistributedObserver: NSObject {
    private let handler: @Sendable () -> Void

    init(name: String, handler: @escaping @Sendable () -> Void) {
        self.handler = handler
        super.init()
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(fire), name: Notification.Name(name), object: nil,
            suspensionBehavior: .deliverImmediately)
    }

    deinit { DistributedNotificationCenter.default().removeObserver(self) }

    @objc private func fire() { handler() }
}

extension Notification.Name {
    /// 전사 완료 브로드캐스트 — 온보딩 튜토리얼이 붙여넣기 경로와 무관하게 결과를 표시하는 데 사용.
    static let badasseoDidTranscribe = Notification.Name("badasseoDidTranscribe")
    /// 온보딩 HotkeyStep의 AX 폴러가 손쉬운 사용 권한 획득을 감지한 시점에 브로드캐스트 —
    /// AppState가 구독해 전역 모니터를 그 자리에서 가동한다(옵트인 완료 즉시 풀가동).
    static let badasseoAXGranted = Notification.Name("badasseoAXGranted")
}
