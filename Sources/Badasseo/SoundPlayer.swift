import AVFoundation

/// 입력 시작/종료음 — 기본 꺼짐(스펙: 기본 무음이 차별점). 설정 토글로만 켬.
@MainActor
final class SoundPlayer {
    static let shared = SoundPlayer()
    private var start: AVAudioPlayer?
    private var stop: AVAudioPlayer?

    private init() {
        start = Self.load("sound-start")
        stop = Self.load("sound-stop")
    }
    private static func load(_ name: String) -> AVAudioPlayer? {
        guard let url = Bundle.module.url(forResource: name, withExtension: "wav"),
              let p = try? AVAudioPlayer(contentsOf: url) else { return nil }
        p.prepareToPlay()
        return p
    }
    private var enabled: Bool { UserDefaults.standard.bool(forKey: "soundFeedback") }  // 기본 false

    func playStart() { guard enabled else { return }; start?.currentTime = 0; start?.play() }
    func playStop() { guard enabled else { return }; stop?.currentTime = 0; stop?.play() }
}
