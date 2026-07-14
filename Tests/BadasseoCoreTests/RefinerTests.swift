import XCTest
@testable import BadasseoCore

final class RefinerTests: XCTestCase {
    let dict = ["깃허브": "GitHub", "풀 리퀘스트": "PR", "풀리퀘스트": "PR"]

    func testDictionarySubstitution() {
        XCTAssertEqual(Refiner.refine("깃허브에 올렸어", dictionary: dict), "GitHub에 올렸어.")
    }
    func testLongestKeyFirst() {
        XCTAssertEqual(Refiner.refine("풀 리퀘스트 보내줘", dictionary: dict), "PR 보내줘.")
    }
    func testWhitespaceCleanup() {
        XCTAssertEqual(Refiner.refine("안녕  하세요 ", dictionary: [:]), "안녕 하세요.")
    }
    func testKeepsExistingTerminalPunctuation() {
        XCTAssertEqual(Refiner.refine("배포했나요?", dictionary: [:]), "배포했나요?")
        XCTAssertEqual(Refiner.refine("좋아요!", dictionary: [:]), "좋아요!")
    }
    func testEmptyInput() {
        XCTAssertEqual(Refiner.refine("", dictionary: dict), "")
        XCTAssertEqual(Refiner.refine("   ", dictionary: dict), "")
    }
}
