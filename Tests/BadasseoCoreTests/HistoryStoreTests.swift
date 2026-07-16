import XCTest
@testable import BadasseoCore

final class HistoryStoreTests: XCTestCase {
    func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathComponent("history.json")
    }
    func testAppendAndPersistAcrossInstances() {
        let url = tempURL()
        HistoryStore(fileURL: url).append("첫 문장")
        let entries = HistoryStore(fileURL: url).entries()
        XCTAssertEqual(entries.map(\.text), ["첫 문장"])   // 새 인스턴스에서도 읽힘 = 저장됨
    }
    func testNewestFirstAndLimit() {
        let url = tempURL()
        let store = HistoryStore(fileURL: url, limit: 3)
        ["a", "b", "c", "d"].forEach { store.append($0) }
        XCTAssertEqual(store.entries().map(\.text), ["d", "c", "b"])  // 최신 앞, a 탈락
    }
    func testIgnoresEmptyText() {
        let url = tempURL()
        let store = HistoryStore(fileURL: url)
        store.append("")
        store.append("   ")
        XCTAssertTrue(store.entries().isEmpty)
    }
    func testClear() {
        let url = tempURL()
        let store = HistoryStore(fileURL: url)
        store.append("x")
        store.clear()
        XCTAssertTrue(store.entries().isEmpty)
        XCTAssertTrue(HistoryStore(fileURL: url).entries().isEmpty)
    }
    func testStandardPathAndDefaultLimit() {
        XCTAssertTrue(HistoryStore.standard.fileURL.path.hasSuffix("Badasseo/history.json"))
        XCTAssertEqual(HistoryStore(fileURL: tempURL()).limit, 500)
    }
}
