import Foundation

/// 발화 끝 음성 명령 — 마지막 단어가 트리거면 그 단어를 빼고 삽입한 뒤 동작 실행.
/// allCases 선언 순서가 중복 트리거 단어의 우선순위다 (스펙: 테이블 순서 우선).
public enum VoiceCommand: String, CaseIterable, Sendable {
    case enter, newline, tab, cancel

    public var defaultTrigger: String {
        switch self {
        case .enter: "엔터"
        case .newline: "줄바꿈"
        case .tab: "탭"
        case .cancel: "취소"
        }
    }
    /// 설정 화면 표기.
    public var displayName: String {
        switch self {
        case .enter: "Enter 입력"
        case .newline: "줄바꿈 (Shift+Enter)"
        case .tab: "다음 필드 (Tab)"
        case .cancel: "받아쓰기 취소"
        }
    }
}

public enum VoiceCommandParser {
    /// 발화 마지막 단어(끝 구두점 무시)를 트리거와 비교해 (키워드 제거 텍스트, 명령)을
    /// 돌려주는 순수 함수. "줄 바꿈"처럼 띄어 전사된 경우를 위해 마지막 두 토큰 결합도
    /// 비교하며, 비교는 공백 제거 + 소문자화로 정규화한다.
    public static func parse(_ text: String, triggers: [VoiceCommand: [String]])
        -> (text: String, command: VoiceCommand?)
    {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // 발화 끝 구두점("엔터.", "엔터!")은 매치를 막지 않도록 벗긴다.
        let punctuation = CharacterSet(charactersIn: ".!?…。,")
        var body = trimmed
        while let last = body.unicodeScalars.last,
              punctuation.contains(last) || last == " " {
            body.unicodeScalars.removeLast()
        }
        let tokens = body.split(separator: " ")
        guard let lastToken = tokens.last else { return (trimmed, nil) }

        func normalized(_ s: String) -> String {
            s.replacingOccurrences(of: " ", with: "").lowercased()
        }
        var candidates = [(word: normalized(String(lastToken)), tokenCount: 1)]
        if tokens.count >= 2 {
            candidates.append((normalized(tokens.suffix(2).joined()), 2))
        }

        for command in VoiceCommand.allCases {
            for trigger in triggers[command] ?? [] {
                let t = normalized(trigger)
                guard !t.isEmpty else { continue }
                for candidate in candidates where candidate.word == t {
                    var remaining = tokens.dropLast(candidate.tokenCount)
                        .joined(separator: " ")
                    // 키워드 직전 쉼표("확인했습니다, 엔터")는 키워드에 딸린 것 — 제거.
                    while let l = remaining.last, l == "," || l == " " {
                        remaining.removeLast()
                    }
                    return (remaining, command)
                }
            }
        }
        return (trimmed, nil)
    }
}
