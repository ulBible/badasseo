import XCTest
@testable import BadasseoCore

final class DictionaryRowsTests: XCTestCase {
    func testRowsSortedBySpoken() {
        let rows = DictionaryRows.rows(from: ["나": "B", "가": "A"])
        XCTAssertEqual(rows.map(\.spoken), ["가", "나"])
        XCTAssertEqual(rows.map(\.written), ["A", "B"])
    }
    func testRoundTrip() {
        let dict = ["깃허브": "GitHub", "커밋": "commit"]
        XCTAssertEqual(DictionaryRows.dictionary(from: DictionaryRows.rows(from: dict)), dict)
    }
    func testDictionaryTrimsAndExcludesInvalid() {
        let rows = [
            DictionaryRows.Row(spoken: " 깃허브 ", written: " GitHub "),
            DictionaryRows.Row(spoken: "", written: "X"),      // 빈 spoken 제외
            DictionaryRows.Row(spoken: "키", written: "   "),   // 빈 written 제외
        ]
        XCTAssertEqual(DictionaryRows.dictionary(from: rows), ["깃허브": "GitHub"])
    }
    func testDuplicateSpokenLastWins() {
        let rows = [
            DictionaryRows.Row(spoken: "키", written: "A"),
            DictionaryRows.Row(spoken: "키", written: "B"),
        ]
        XCTAssertEqual(DictionaryRows.dictionary(from: rows), ["키": "B"])
    }
    func testIsValid() {
        XCTAssertTrue(DictionaryRows.Row(spoken: "가", written: "A").isValid)
        XCTAssertFalse(DictionaryRows.Row(spoken: " ", written: "A").isValid)
        XCTAssertFalse(DictionaryRows.Row(spoken: "가", written: "").isValid)
    }
    func testStandardPath() {
        XCTAssertTrue(UserDictionary.standard.fileURL.path.hasSuffix("Badasseo/dictionary.json"))
    }
}
