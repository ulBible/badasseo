import XCTest
@testable import BadasseoCore

final class ProcessUsageTests: XCTestCase {
    func testCPUTimeGrowsWhileWorking() throws {
        let before = try XCTUnwrap(ProcessUsage.current())
        var x = 0.0
        for i in 0..<5_000_000 { x += Double(i).squareRoot() }
        XCTAssertGreaterThan(x, 0)
        let after = try XCTUnwrap(ProcessUsage.current())
        XCTAssertGreaterThan(after.cpuSeconds, before.cpuSeconds)
    }

    func testDiskBytesReadNeverDecreases() throws {
        let before = try XCTUnwrap(ProcessUsage.current())
        let after = try XCTUnwrap(ProcessUsage.current())
        XCTAssertGreaterThanOrEqual(after.diskBytesRead, before.diskBytesRead)
    }

    func testDeltaReportsDifferenceSinceEarlierSnapshot() {
        let before = ProcessUsage(cpuSeconds: 1.0, diskBytesRead: 10 * 1_048_576)
        let after = ProcessUsage(cpuSeconds: 1.5, diskBytesRead: 110 * 1_048_576)
        let delta = after.delta(since: before)
        XCTAssertEqual(delta.cpuSeconds, 0.5, accuracy: 0.0001)
        XCTAssertEqual(delta.diskMegabytesRead, 100, accuracy: 0.0001)
    }
}
