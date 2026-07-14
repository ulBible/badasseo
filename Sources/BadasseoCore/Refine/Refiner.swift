import Foundation

/// 규칙 기반 한국어 후처리 — 사전 치환 + 공백 정리 + 종결부호 보정. LLM 없음(벤치 기각).
public enum Refiner {
    public static func refine(_ text: String, dictionary: [String: String]) -> String {
        var t = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard !t.isEmpty else { return "" }
        for key in dictionary.keys.sorted(by: { $0.count > $1.count }) {  // 긴 키 우선
            t = t.replacingOccurrences(of: key, with: dictionary[key]!)
        }
        if let last = t.last, !".?!".contains(last) { t += "." }
        return t
    }
}
