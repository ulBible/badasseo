import SwiftUI
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
    private var engine: WhisperEngine?
    /// 진행 중인 엔진 로드(single-flight). 로드가 끝나기 전에 받아쓰기를 다시 시도해도
    /// 이 Task를 공유한다 — 시도마다 1.6GB 엔진을 새로 만들면 GPU 메모리가 고갈되어
    /// Metal residency 요청이 무한 재시도에 빠진다(실측: 재시도 9회 = 16GB, 전사 영구 멈춤).
    private var engineLoad: Task<WhisperEngine?, Never>?
    private let modifierHoldMonitor = ModifierHoldMonitor()
    private var noSpeechGeneration = 0

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
        // 온보딩에서 방금 권한을 부여한 경로(HotkeyStep의 AX 폴러)를 연결.
        NotificationCenter.default.addObserver(forName: .badasseoAXGranted, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.modifierHoldMonitor.installGlobalMonitorsIfNeeded() }
        }
        // 설정 앱에서 수동으로 권한을 켜고 돌아온 경우(온보딩 폴러를 거치지 않는 경로)도 커버.
        NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.modifierHoldMonitor.installGlobalMonitorsIfNeeded() }
        }
        // custom 모드가 아니면 Carbon 핫키 등록을 비활성 — 등록만으로도 ⌥Space가
        // 시스템 전역에서 소비되어(Alfred 등과 충돌) "무간섭" 원칙을 깬다.
        // 모드 전환 시 GeneralTab이 enable/disable을 토글한다.
        if Self.hotkeyMode != "custom" { KeyboardShortcuts.disable(.pushToTalk) }
    }

    private func beginRecording() {
        // .error에서도 시작 허용 — 레코딩 재시도가 곧 에러 해제. (에러 문구는 다음 시도까지 메뉴에 유지)
        switch status { case .idle, .error, .noSpeech: break; default: return }
        // 모델이 준비되기 전에는 녹음 자체를 시작하지 않는다 (마이크·효과음 비활성) —
        // 다운로드 중 단축키를 눌러도 마이크가 켜지거나 시작음이 나지 않아야 한다.
        guard let size = try? FileManager.default.attributesOfItem(atPath: modelPath)[.size] as? Int64,
              size == ModelInfo.byteSize else {
            status = .error("모델 다운로드가 끝나면 사용할 수 있어요")
            return
        }
        do {
            try capture.start()
            status = .recording
            // 시작음은 의도적으로 즉시 재생 — "녹음이 시작됐다"는 피드백이 목적이라 지연 불가.
            // 조합 취소(cancelRecording) 시 종료음만 억제됨: 시작음이 이미 난 것은 수용된 트레이드오프
            // (opt-in 설정 + 취소는 mic 데이터도 폐기되므로 내용 유출 없음).
            SoundPlayer.shared.playStart()
        } catch { status = .error("마이크 시작 실패") }
    }

    /// 홀드 중 다른 키가 눌려 조합 단축키로 판정된 경우 — 전사하지 않고 녹음을 폐기.
    private func cancelRecording() {
        activeHotkeySource = nil
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
        // 모델 로드(1.6GB whisper_init)는 반드시 메인 스레드 밖에서 — @MainActor 메서드로
        // 감싸면 detached여도 로드가 메인으로 홉해서 UI가 얼어붙는다.
        // 로드는 single-flight: 이미 진행 중이면 그 Task의 결과를 기다린다(주석 참고: engineLoad).
        let modelPath = self.modelPath
        let load: Task<WhisperEngine?, Never>
        if let engine {
            load = Task { engine }
        } else if let inFlight = engineLoad {
            load = inFlight
        } else {
            load = Task.detached(priority: .userInitiated) {
                try? WhisperEngine(modelPath: modelPath)
            }
            engineLoad = load
        }
        Task.detached(priority: .userInitiated) { [weak self] in
            let engine: WhisperEngine? = await load.value
            guard let engine else {
                await MainActor.run {
                    self?.engineLoad = nil  // 실패한 로드는 버려서 다음 시도가 새로 로드하게
                    self?.status = .error("모델 없음: \(modelPath)")
                }
                return
            }
            do {
                let raw = try engine.transcribe(samples: samples, promptTerms: terms)
                let refined = Refiner.refine(raw, dictionary: dict)
                // 음성 명령: 정제 후 마지막 단어를 검사. 토글 OFF면 파서를 타지 않아
                // 키워드가 일반 텍스트로 그대로 삽입된다.
                let (finalText, command) = VoiceCommandSettings.isEnabled()
                    ? VoiceCommandParser.parse(refined, triggers: VoiceCommandSettings.triggers())
                    : (refined, nil)
                await MainActor.run {
                    guard let self else { return }
                    self.engine = engine  // 캐시 (다음부터 재사용) — 할당은 MainActor에서만
                    // 온보딩 창이 떠 있으면 자동 삽입(⌘V 합성)을 건너뛴다 — 튜토리얼은
                    // 아래 알림 경로로만 입력칸에 표시하므로, ⌘V까지 하면 이중 입력이 된다.
                    // key window일 때만 건너뛴다(visible이 아님) — 온보딩 창을 뒤로 둔 채
                    // 다른 앱에 받아쓰면 정상 삽입돼야 한다(전사 유실 방지).
                    let onboardingActive = NSApp.windows.contains {
                        $0.identifier?.rawValue == "onboarding" && $0.isKeyWindow
                    }
                    if command == .cancel {
                        // 폐기 — 삽입·히스토리·브로드캐스트 없음. 유일한 피드백은
                        // 확인음(화면 신호가 없는 경로라 소리가 폐기 사실을 알린다).
                        SoundPlayer.shared.playCommand()
                        self.status = .idle
                    } else if finalText.isEmpty, let command {
                        // 명령 단독 발화("엔터") — 붙여넣기 없이 키만
                        if !onboardingActive {
                            TextInserter.press(command)
                            SoundPlayer.shared.playCommand()
                        }
                        self.status = .idle
                    } else if finalText.isEmpty || SpeechGate.isJunk(finalText) {
                        self.showNoSpeech()  // 무음·잡음·환각 토큰 — 삽입하지 않음 (스펙)
                    } else {
                        if !onboardingActive {
                            switch TextInserter.insert(finalText) {
                            case .copiedOnly:
                                Notifier.copiedOnly()  // 키 합성도 불가한 상태 — 명령 생략
                            case .pasted:
                                if let command {
                                    // 대상 앱이 ⌘V를 소화한 뒤 키가 도착해야 한다 (스펙: 0.25초).
                                    // 그 사이 새 녹음이 시작됐으면(상태 변화) 키를 쏘지 않는다 —
                                    // 지연된 Return이 다른 맥락에 꽂히는 사고 방지.
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                                        guard let self, case .idle = self.status else { return }
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
                }
            } catch {
                await MainActor.run { self?.status = .error("전사 실패 — 다시 시도해 주세요") }
                return
            }
        }
    }
}

extension Notification.Name {
    /// 전사 완료 브로드캐스트 — 온보딩 튜토리얼이 붙여넣기 경로와 무관하게 결과를 표시하는 데 사용.
    static let badasseoDidTranscribe = Notification.Name("badasseoDidTranscribe")
    /// 온보딩 HotkeyStep의 AX 폴러가 손쉬운 사용 권한 획득을 감지한 시점에 브로드캐스트 —
    /// AppState가 구독해 전역 모니터를 그 자리에서 가동한다(옵트인 완료 즉시 풀가동).
    static let badasseoAXGranted = Notification.Name("badasseoAXGranted")
}
