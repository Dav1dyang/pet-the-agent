import XCTest
@testable import PetTheAgent

final class HingeReportDecoderTests: XCTestCase {
    func testPreciseReportUsesHundredthsOfDegree() {
        XCTAssertEqual(HingeReportDecoder.degrees(from: [7, 0xFB, 0x2B], reportID: 7), 112.59)
    }

    func testCoarseReportUsesWholeDegrees() {
        XCTAssertEqual(HingeReportDecoder.degrees(from: [1, 113, 0], reportID: 1), 113)
    }

    func testRejectsInvalidReadings() {
        XCTAssertNil(HingeReportDecoder.degrees(from: [7, 0xFF], reportID: 7))
        XCTAssertNil(HingeReportDecoder.degrees(from: [7, 0xFF, 0xFF], reportID: 7))
    }
}
