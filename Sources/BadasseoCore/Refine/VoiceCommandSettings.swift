import Foundation

/// 음성 명령 설정 — 마스터 토글 + 명령별 트리거 단어(쉼표 구분 문자열).
/// SettingsView의 @AppStorage와 같은 키를 공유한다.
public enum VoiceCommandSettings {
    public static let enabledKey = "voiceCommandsEnabled"

    public static func isEnabled(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: enabledKey) as? Bool ?? true
    }

    public static func triggersKey(_ command: VoiceCommand) -> String {
        "voiceCommandTriggers.\(command.rawValue)"
    }

    /// 저장값이 없으면 기본 트리거 1개, 있으면 쉼표 분리(공백 정리, 빈 항목 제외).
    /// 빈 문자열 저장 = 그 명령 비활성.
    public static func words(for command: VoiceCommand,
                             _ defaults: UserDefaults = .standard) -> [String] {
        guard let stored = defaults.string(forKey: triggersKey(command)) else {
            return [command.defaultTrigger]
        }
        return stored.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    public static func triggers(_ defaults: UserDefaults = .standard)
        -> [VoiceCommand: [String]]
    {
        Dictionary(uniqueKeysWithValues:
            VoiceCommand.allCases.map { ($0, words(for: $0, defaults)) })
    }
}
