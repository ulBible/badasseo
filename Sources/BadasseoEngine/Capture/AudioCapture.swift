@preconcurrency import AVFoundation

/// 푸시투토크 녹음: start()~stop() 사이 마이크 입력을 16kHz mono Float로 축적.
///
/// `@unchecked Sendable`: `installTap`의 콜백은 CoreAudio가 임의 스레드에서
/// 호출하며, 캡처하는 `converter`/`samples`는 `NSLock`으로 직접 보호한다
/// (Swift 6 strict concurrency가 요구하는 격리 대신 수동 락으로 계약을 만족).
/// 호출자는 `start()`/`stop()`을 동시에 호출하지 않아야 한다(직렬 사용 책임).
public final class AudioCapture: @unchecked Sendable {
    private let engine = AVAudioEngine()
    private var samples: [Float] = []
    private var converter: AVAudioConverter?
    private let lock = NSLock()

    public init() {}

    public func start() throws {
        samples = []
        let input = engine.inputNode
        let inFormat = input.outputFormat(forBus: 0)
        let target = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                   sampleRate: 16000, channels: 1, interleaved: false)!
        converter = AVAudioConverter(from: inFormat, to: target)
        input.installTap(onBus: 0, bufferSize: 4096, format: inFormat) { [weak self] buf, _ in
            guard let self, let conv = self.converter else { return }
            let cap = AVAudioFrameCount(Double(buf.frameLength) * 16000.0 / inFormat.sampleRate) + 256
            guard let out = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: cap) else { return }
            var fed = false
            conv.convert(to: out, error: nil) { _, status in
                if fed { status.pointee = .noDataNow; return nil }
                fed = true; status.pointee = .haveData; return buf
            }
            let chunk = Array(UnsafeBufferPointer(start: out.floatChannelData![0],
                                                  count: Int(out.frameLength)))
            self.lock.lock(); self.samples.append(contentsOf: chunk); self.lock.unlock()
        }
        engine.prepare()
        try engine.start()
    }

    public func stop() -> [Float] {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        lock.lock(); defer { lock.unlock() }
        return samples
    }
}
