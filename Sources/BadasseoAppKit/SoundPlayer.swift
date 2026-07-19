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
    // 소리별 개별 토글. 개별 키 미존재 시 기존 통합 키("soundFeedback")를 따르고
    // (과거에 꺼둔 사용자 유지), 그것도 없으면 켜짐.
    static let startKey = "soundStartEnabled"
    static let stopKey = "soundStopEnabled"
    static let commandKey = "soundCommandEnabled"
    static func isEnabled(_ key: String) -> Bool {
        if let v = UserDefaults.standard.object(forKey: key) as? Bool { return v }
        return UserDefaults.standard.object(forKey: "soundFeedback") as? Bool ?? true
    }

    func playStart() { guard Self.isEnabled(Self.startKey) else { return }; start?.currentTime = 0; start?.play() }
    func playStop() { guard Self.isEnabled(Self.stopKey) else { return }; stop?.currentTime = 0; stop?.play() }
    /// 음성 명령 실행 확인음.
    func playCommand() { guard Self.isEnabled(Self.commandKey) else { return }; command?.currentTime = 0; command?.play() }
}
