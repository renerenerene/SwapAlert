import XCTest
@testable import SwapAlert

final class MemoryReaderTests: XCTestCase {
    func testSnapshotContainsSensibleSystemValues() throws {
        let snapshot = try MemoryReader.snapshot()

        XCTAssertGreaterThan(snapshot.pageSize, 0)
        if let used = snapshot.swapUsedBytes, let total = snapshot.swapTotalBytes {
            XCTAssertGreaterThanOrEqual(total, used)
        } else {
            XCTAssertNil(snapshot.swapUsedBytes)
            XCTAssertNil(snapshot.swapTotalBytes)
        }
    }
}
