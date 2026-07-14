import AVFoundation

public enum WavLoader {
    /// 임의 오디오 파일 → 16kHz mono Float32 샘플.
    public static func loadSamples(url: URL) throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        let target = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                   sampleRate: 16000, channels: 1, interleaved: false)!
        let converter = AVAudioConverter(from: file.processingFormat, to: target)!
        let inBuf = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                     frameCapacity: AVAudioFrameCount(file.length))!
        try file.read(into: inBuf)
        let ratio = 16000.0 / file.processingFormat.sampleRate
        let outCap = AVAudioFrameCount(Double(inBuf.frameLength) * ratio) + 1024
        let outBuf = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: outCap)!
        var fed = false
        var err: NSError?
        converter.convert(to: outBuf, error: &err) { _, status in
            if fed { status.pointee = .endOfStream; return nil }
            fed = true; status.pointee = .haveData; return inBuf
        }
        if let err { throw err }
        return Array(UnsafeBufferPointer(start: outBuf.floatChannelData![0],
                                         count: Int(outBuf.frameLength)))
    }
}
