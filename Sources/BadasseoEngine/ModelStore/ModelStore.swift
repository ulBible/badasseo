import Foundation
import BadasseoCore

/// 모델 다운로드 매니저 — 이어받기 + SHA256 검증. 온보딩 2단계·설정에서 공용.
@MainActor
public final class ModelStore: NSObject, ObservableObject {
    public enum State: Equatable {
        case idle, downloading(Double), verifying, ready, failed(String)
    }
    @Published public private(set) var state: State = .idle

    private var task: URLSessionDownloadTask?
    private var resumeData: Data?
    private lazy var session = URLSession(configuration: .default, delegate: self, delegateQueue: .main)

    public func ensureModel() {
        if case .downloading = state { return }
        if case .verifying = state { return }
        if case .ready = state { return }
        let dest = ModelInfo.destination
        if let size = try? FileManager.default.attributesOfItem(atPath: dest.path)[.size] as? Int64,
           size == ModelInfo.byteSize {
            state = .ready   // 기존 파일(수동 복사 포함) — 크기 일치면 통과 (전체 해시는 다운로드 시에만)
            return
        }
        startDownload()
    }

    public func startDownload() {
        if case .downloading = state { return }
        if case .verifying = state { return }
        state = .downloading(0)
        task = resumeData.map { session.downloadTask(withResumeData: $0) }
            ?? session.downloadTask(with: ModelInfo.url)
        resumeData = nil
        task?.resume()
    }

    private func verify(fileAt tmp: URL) {
        state = .verifying
        Task.detached(priority: .userInitiated) {  // 1.6GB 해시 — 메인 밖
            let result: Result<Void, Error> = Result {
                let data = try Data(contentsOf: tmp, options: .mappedIfSafe)
                guard ModelInfo.hex(sha256Of: data) == ModelInfo.sha256 else {
                    throw NSError(domain: "Badasseo", code: 1,
                                  userInfo: [NSLocalizedDescriptionKey: "체크섬 불일치"])
                }
                let dest = ModelInfo.destination
                try FileManager.default.createDirectory(at: dest.deletingLastPathComponent(),
                                                        withIntermediateDirectories: true)
                _ = try? FileManager.default.removeItem(at: dest)
                try FileManager.default.moveItem(at: tmp, to: dest)
            }
            await MainActor.run { [weak self] in
                switch result {
                case .success: self?.state = .ready
                case .failure(let e):
                    try? FileManager.default.removeItem(at: tmp)
                    self?.state = .failed("다운로드 파일 검증 실패 — 다시 받아주세요 (\(e.localizedDescription))")
                }
            }
        }
    }
}

extension ModelStore: URLSessionDownloadDelegate {
    public nonisolated func urlSession(_ s: URLSession, downloadTask: URLSessionDownloadTask,
                                       didWriteData: Int64, totalBytesWritten: Int64,
                                       totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let p = Double(totalBytesWritten) / Double(max(totalBytesExpectedToWrite, 1))
        Task { @MainActor [weak self] in
            if case .downloading = self?.state { self?.state = .downloading(p) }
        }
    }
    public nonisolated func urlSession(_ s: URLSession, downloadTask: URLSessionDownloadTask,
                                       didFinishDownloadingTo location: URL) {
        // location은 델리게이트 리턴 후 삭제됨 — 즉시 안전한 위치로 이동
        let hold = FileManager.default.temporaryDirectory
            .appendingPathComponent("badasseo-model-\(UUID().uuidString).tmp")
        do {
            try FileManager.default.moveItem(at: location, to: hold)
        } catch {
            Task { @MainActor [weak self] in
                self?.state = .failed("다운로드 파일 이동 실패 — 디스크 공간을 확인해 주세요")
            }
            return
        }
        Task { @MainActor [weak self] in self?.verify(fileAt: hold) }
    }
    public nonisolated func urlSession(_ s: URLSession, task: URLSessionTask,
                                       didCompleteWithError error: Error?) {
        guard let error = error as NSError? else { return }
        let resume = error.userInfo[NSURLSessionDownloadTaskResumeData] as? Data
        Task { @MainActor [weak self] in
            self?.resumeData = resume
            self?.state = .failed("다운로드 실패 — 네트워크 확인 후 다시 시도해 주세요")
        }
    }
}
