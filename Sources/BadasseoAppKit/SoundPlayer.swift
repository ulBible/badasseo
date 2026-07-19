import AVFoundation

/// 입력 시작/종료음 — 기본 꺼짐(스펙: 기본 무음이 차별점). 설정 토글로만 켬.
@MainActor
final class SoundPlayer {
    static let shared = SoundPlayer()
    private var start: AVAudioPlayer?
    private var stop: AVAudioPlayer?
    private var command: AVAudioPlayer?

    private init() {
        start = Self.load("sound-start")
        stop = Self.load("sound-stop")
        command = Self.load("sound-command")
    }
    private static func load(_ name: String) -> AVAudioPlayer? {
        guard let url = Bundle.module.url(forResource: name, withExtension: "wav"),
              let p = try? AVAudioPlayer(contentsOf: url) else { return nil }
        p.prepareToPlay()
        return p
    }
    // 기본 켜짐 (2026-07-17 Bible 결정 — 자체 사운드가 절제된 톤이라 기본 경험에 포함).
    // 키 미존재 = true, 사용자가 명시적으로 끈 경우만 false.
    private var enabled: Bool {
        UserDefaults.standard.object(forKey: "soundFeedback") as? Bool ?? true
    }

    func playStart() { guard enabled else { return }; start?.currentTime = 0; start?.play() }
    func playStop() { guard enabled else { return }; stop?.currentTime = 0; stop?.play() }
    /// 음성 명령 실행 확인음 — 시작/종료음(518/391Hz)과 구분되는 상승 2음(G5→C6).
    func playCommand() { guard enabled else { return }; command?.currentTime = 0; command?.play() }
}
