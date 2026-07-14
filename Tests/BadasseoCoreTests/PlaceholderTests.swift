import XCTest
@testable import BadasseoCore
final class PlaceholderTests: XCTestCase {
    func testVersion() { XCTAssertEqual(BadasseoCore.version, "0.1.0") }
}
