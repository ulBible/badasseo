import SwiftUI
import KeyboardShortcuts
import BadasseoCore
import BadasseoEngine

extension KeyboardShortcuts.Name {
    static let pushToTalk = Self("pushToTalk", default: .init(.space, modifiers: [.option]))
}

@MainActor
final class AppState: ObservableObject {
    enum Status { case idle, recording, processing, error(String) }
    @Published var status: Status = .idle
    @Published var lastResult: String = ""
    @Published private(set) var recent: [HistoryEntry] = []

    private let support = FileManager.default.urls(for: .applicationSupportDirectory,
                                                   in: .userDomainMask)[0]
        .appendingPathComponent("Badasseo")
    private lazy var dictionary = UserDictionary(fileURL: support.appendingPathComponent("dictionary.json"))
    private(set) lazy var history = HistoryStore(fileURL: support.appendingPathComponent("history.json"))
    private let capture = AudioCapture()
    private var engine: WhisperEngine?

    var modelPath: String {
        support.appendingPathComponent("models/ggml-large-v3-turbo.bin").path
    }

    init() {
        recent = history.entries()
        KeyboardShortcuts.onKeyDown(for: .pushToTalk) { [weak self] in self?.beginRecording() }
        KeyboardShortcuts.onKeyUp(for: .pushToTalk) { [weak self] in self?.endRecording() }
    }

    private func beginRecording() {
        // .error에서도 시작 허용 — 레코딩 재시도가 곧 에러 해제. (에러 문구는 다음 시도까지 메뉴에 유지)
        switch status { case .idle, .error: break; default: return }
        do { try capture.start(); status = .recording } catch { status = .error("마이크 시작 실패") }
    }

    private func endRecording() {
        guard case .recording = status else { return }
        let samples = capture.stop()
        status = .processing
        guard samples.count > 8000 else { status = .idle; return }  // <0.5초 = 무시
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
            let raw = engine.transcribe(samples: samples, promptTerms: terms)
            let refined = Refiner.refine(raw, dictionary: dict)
            await MainActor.run {
                guard let self else { return }
                self.engine = engine  // 캐시 (다음부터 재사용) — 할당은 MainActor에서만
                if refined.isEmpty {
                    self.status = .idle  // 무음·잡음 — 삽입하지 않음 (스펙)
                } else {
                    TextInserter.insert(refined)
                    self.history.append(refined)
                    self.recent = self.history.entries()
                    self.lastResult = refined
                    self.status = .idle
                }
            }
        }
    }
}
