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
    @Published var status: Status = .idle
    @Published var lastResult: String = ""

    private let support = FileManager.default.urls(for: .applicationSupportDirectory,
                                                   in: .userDomainMask)[0]
        .appendingPathComponent("Badasseo")
    private lazy var dictionary = UserDictionary.standard
    private(set) lazy var history = HistoryStore.standard
    private let capture = AudioCapture()
    private var engine: WhisperEngine?
    private let modifierHoldMonitor = ModifierHoldMonitor()

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
        // custom 모드가 아니면 Carbon 핫키 등록을 비활성 — 등록만으로도 ⌥Space가
        // 시스템 전역에서 소비되어(Alfred 등과 충돌) "무간섭" 원칙을 깬다.
        // 모드 전환 시 GeneralTab이 enable/disable을 토글한다.
        if Self.hotkeyMode != "custom" { KeyboardShortcuts.disable(.pushToTalk) }
    }

    private func beginRecording() {
        // .error에서도 시작 허용 — 레코딩 재시도가 곧 에러 해제. (에러 문구는 다음 시도까지 메뉴에 유지)
        switch status { case .idle, .error: break; default: return }
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
        status = .noSpeech
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            if case .noSpeech = self.status { self.status = .idle }
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
        // 모델 로드(1.6GB whisper_init)는 반드시 메인 스레드 밖에서 — @MainActor 메서드로
        // 감싸면 detached여도 로드가 메인으로 홉해서 UI가 얼어붙는다.
        let existing = engine
        let modelPath = self.modelPath
        Task.detached(priority: .userInitiated) { [weak self] in
            let engine: WhisperEngine? = existing ?? (try? WhisperEngine(modelPath: modelPath))
            guard let engine else {
                await MainActor.run { self?.status = .error("모델 없음: \(modelPath)") }
                return
            }
            do {
                let raw = try engine.transcribe(samples: samples, promptTerms: terms)
                let refined = Refiner.refine(raw, dictionary: dict)
                await MainActor.run {
                    guard let self else { return }
                    self.engine = engine  // 캐시 (다음부터 재사용) — 할당은 MainActor에서만
                    if refined.isEmpty || SpeechGate.isJunk(refined) {
                        self.showNoSpeech()  // 무음·잡음·환각 토큰 — 삽입하지 않음 (스펙)
                    } else {
                        if TextInserter.insert(refined) == .copiedOnly {
                            Notifier.copiedOnly()
                        }
                        self.history.append(refined)
                        self.lastResult = refined
                        self.status = .idle
                    }
                }
            } catch {
                await MainActor.run { self?.status = .error("전사 실패 — 다시 시도해 주세요") }
                return
            }
        }
    }
}
