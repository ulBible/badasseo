import XCTest
@testable import BadasseoCore

final class UserDictionaryTests: XCTestCase {
    func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathComponent("dictionary.json")
    }
    func testLoadCreatesSeedWhenMissing() throws {
        let url = tempURL()
        let d = UserDictionary(fileURL: url)
        let loaded = d.load()
        XCTAssertEqual(loaded["깃허브"], "GitHub")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))  // 시드가 파일로 생성됨
    }
    func testSaveThenLoadRoundTrip() throws {
        let url = tempURL()
        let d = UserDictionary(fileURL: url)
        d.save(["보이스잉크": "VoiceInk"])
        XCTAssertEqual(d.load(), ["보이스잉크": "VoiceInk"])
    }
    func testPromptTermsAreSortedUniqueValues() throws {
        let url = tempURL()
        let d = UserDictionary(fileURL: url)
        d.save(["a": "PR", "b": "GitHub", "c": "PR"])
        XCTAssertEqual(d.promptTerms(), ["GitHub", "PR"])
    }
    func testLoadFallsBackToSeedOnCorruptFile() throws {
        let url = tempURL()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: url)
        XCTAssertEqual(UserDictionary(fileURL: url).load()["깃허브"], "GitHub")
    }
}
