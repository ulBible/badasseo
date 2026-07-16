import Foundation

/// 설정 창의 행 목록 ↔ 사전 변환 — UI의 유일한 로직이라 테스트로 고정.
public enum DictionaryRows {
    public struct Row: Identifiable, Equatable {
        public var id: UUID
        public var spoken: String   // 말한 것
        public var written: String  // 쓸 것
        public init(id: UUID = UUID(), spoken: String, written: String) {
            self.id = id
            self.spoken = spoken
            self.written = written
        }
        public var isValid: Bool {
            !spoken.trimmingCharacters(in: .whitespaces).isEmpty
                && !written.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    public static func rows(from dict: [String: String]) -> [Row] {
        dict.keys.sorted().map { Row(spoken: $0, written: dict[$0]!) }
    }

    public static func dictionary(from rows: [Row]) -> [String: String] {
        var out: [String: String] = [:]
        for row in rows where row.isValid {
            out[row.spoken.trimmingCharacters(in: .whitespaces)] =
                row.written.trimmingCharacters(in: .whitespaces)
        }
        return out
    }
}
