import Foundation

public struct HistoryEntry: Codable, Equatable {
    public let text: String
    public let date: Date
}

/// 최근 전사 결과 로컬 JSON 보관 — 서버 전송 없음 (프라이버시).
public final class HistoryStore {
    let fileURL: URL
    let limit: Int
    public init(fileURL: URL, limit: Int = 500) {
        self.fileURL = fileURL
        self.limit = limit
    }
    public func entries() -> [HistoryEntry] {
        guard let data = try? Data(contentsOf: fileURL),
              let list = try? JSONDecoder().decode([HistoryEntry].self, from: data)
        else { return [] }
        return list
    }
    public func append(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var list = entries()
        list.insert(HistoryEntry(text: trimmed, date: Date()), at: 0)
        write(Array(list.prefix(limit)))
    }
    public func clear() { write([]) }

    private func write(_ list: [HistoryEntry]) {
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(list) { try? data.write(to: fileURL) }
    }
}

public extension HistoryStore {
    /// 앱 표준 히스토리 파일 — AppState·설정 창의 단일 경로 출처.
    static var standard: HistoryStore {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Badasseo/history.json")
        return HistoryStore(fileURL: url)
    }
}
