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
        KeyboardShortcuts.onKeyDown(for: .pushToTalk) { [weak self] in self?.beginRecording() }
        KeyboardShortcuts.onKeyUp(for: .pushToTalk) { [weak self] in self?.endRecording() }
    }

    private func loadEngineIfNeeded() -> WhisperEngine? {
        if engine == nil {
            engine = try? WhisperEngine(modelPath: modelPath)
            if engine == nil { status = .error("모델 없음: \(modelPath)") }
        }
        return engine
    }

    private func beginRecording() {
        guard case .idle = status else { return }
        do { try capture.start(); status = .recording } catch { status = .error("마이크 시작 실패") }
    }

    private func endRecording() {
        guard case .recording = status else { return }
        let samples = capture.stop()
        status = .processing
        guard samples.count > 8000 else { status = .idle; return }  // <0.5초 = 무시
        let dict = dictionary.load()
        let terms = dictionary.promptTerms()
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self, let engine = await self.loadEngineIfNeeded() else { return }
            let raw = engine.transcribe(samples: samples, promptTerms: terms)
            let refined = Refiner.refine(raw, dictionary: dict)
            await MainActor.run {
                if refined.isEmpty {
                    self.status = .idle  // 무음·잡음 — 삽입하지 않음 (스펙)
                } else {
                    TextInserter.insert(refined)
                    self.history.append(refined)
                    self.lastResult = refined
                    self.status = .idle
                }
            }
        }
    }
}
