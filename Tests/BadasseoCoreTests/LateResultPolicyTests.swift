import XCTest
@testable import BadasseoCore

final class LateResultPolicyTests: XCTestCase {
    func testSameFrontmostAppInserts() {
        XCTAssertEqual(LateResultPolicy.decide(frontmostAtKeyUp: 501, frontmostNow: 501), .insert)
    }

    /// 전사가 끝났을 때 다른 앱이 앞에 있으면 거기에 붙여넣거나 Return을 보내면 안 된다.
    func testDifferentFrontmostAppOnlyCopies() {
        XCTAssertEqual(LateResultPolicy.decide(frontmostAtKeyUp: 501, frontmostNow: 777), .copyOnly)
    }

    func testUnknownOnBothSidesInserts() {
        XCTAssertEqual(LateResultPolicy.decide(frontmostAtKeyUp: nil, frontmostNow: nil), .insert)
    }

    func testUnknownOnOneSideOnlyCopies() {
        XCTAssertEqual(LateResultPolicy.decide(frontmostAtKeyUp: 501, frontmostNow: nil), .copyOnly)
        XCTAssertEqual(LateResultPolicy.decide(frontmostAtKeyUp: nil, frontmostNow: 501), .copyOnly)
    }
}
