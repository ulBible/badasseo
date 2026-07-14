import Foundation

/// {말한 것 → 쓸 것} 사용자 사전. 파일 없거나 깨지면 기본 시드로 복원.
public struct UserDictionary {
    public static let defaultSeed: [String: String] = [
        "깃허브": "GitHub", "깃 허브": "GitHub",
        "풀 리퀘스트": "PR", "풀리퀘스트": "PR",
        "리베이스": "rebase", "클로드": "Claude", "맥북": "MacBook",
        "슬랙": "Slack", "노션": "Notion", "커밋": "commit", "브랜치": "branch",
    ]
    let fileURL: URL
    public init(fileURL: URL) { self.fileURL = fileURL }

    public func load() -> [String: String] {
        if let data = try? Data(contentsOf: fileURL),
           let dict = try? JSONDecoder().decode([String: String].self, from: data) {
            return dict
        }
        save(Self.defaultSeed)  // 시드를 파일로 만들어 사용자가 편집 가능하게
        return Self.defaultSeed
    }

    public func save(_ dict: [String: String]) {
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(dict) { try? data.write(to: fileURL) }
    }

    public func promptTerms() -> [String] { Array(Set(load().values)).sorted() }
}
