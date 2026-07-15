import Foundation
import whisper

public enum WhisperError: Error { case modelLoadFailed(String), transcribeFailed(Int32) }

/// whisper.cpp 상주 래퍼 — ko 고정, 번역 금지 (스펙 쐐기 ①).
///
/// `@unchecked Sendable`: ctx(OpaquePointer)는 whisper.h 주석대로
/// "thread-safe as long as the same whisper_context is not used by multiple
/// threads concurrently" — 이 클래스는 그 계약을 그대로 넘겨받는다(내부에서
/// 추가 동기화를 하지 않음). 호출자가 단일 스레드/직렬 큐에서만 호출해야
/// 하는 책임을 진다. Swift 6 strict concurrency가 OpaquePointer 캡처에
/// 대해 Sendable 부재를 경고하므로, 위 계약을 문서화하는 조건으로 명시.
public final class WhisperEngine: @unchecked Sendable {
    private let ctx: OpaquePointer

    public init(modelPath: String) throws {
        var cparams = whisper_context_default_params()
        cparams.use_gpu = true  // Metal
        guard let ctx = whisper_init_from_file_with_params(modelPath, cparams) else {
            throw WhisperError.modelLoadFailed(modelPath)
        }
        self.ctx = ctx
    }
    deinit { whisper_free(ctx) }

    public func transcribe(samples: [Float], promptTerms: [String] = []) throws -> String {
        var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        params.print_progress = false
        params.print_realtime = false
        params.print_timestamps = false
        params.translate = false
        params.no_timestamps = true
        params.single_segment = false
        let prompt = promptTerms.joined(separator: ", ")
        return try "ko".withCString { ko in
            params.language = ko
            return try prompt.withCString { p in
                if !promptTerms.isEmpty { params.initial_prompt = p }
                var out = ""
                let rc = samples.withUnsafeBufferPointer { buf in
                    whisper_full(ctx, params, buf.baseAddress, Int32(buf.count))
                }
                guard rc == 0 else { throw WhisperError.transcribeFailed(rc) }
                for i in 0..<whisper_full_n_segments(ctx) {
                    out += String(cString: whisper_full_get_segment_text(ctx, i))
                }
                return out.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
    }
}
