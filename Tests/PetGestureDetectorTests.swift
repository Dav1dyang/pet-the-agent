import XCTest
@testable import PetTheAgent

final class PetGestureDetectorTests: XCTestCase {
    func testSmallOutAndBackTriggersOnce() {
        var detector = PetGestureDetector()
        XCTAssertFalse(detector.consume(angle: 110, at: 1.00))
        XCTAssertFalse(detector.consume(angle: 111, at: 1.10))
        XCTAssertFalse(detector.consume(angle: 112, at: 1.20))
        XCTAssertFalse(detector.consume(angle: 113, at: 1.30))
        XCTAssertTrue(detector.consume(angle: 111, at: 1.45))
        XCTAssertFalse(detector.consume(angle: 113, at: 1.60))
        XCTAssertFalse(detector.consume(angle: 111, at: 1.75))
    }

    func testNoiseAndOneWayMovementDoNotTrigger() {
        var detector = PetGestureDetector()
        for (index, angle) in [110.0, 110, 111, 110, 111, 110, 109, 110].enumerated() {
            XCTAssertFalse(detector.consume(angle: angle, at: Double(index) * 0.1))
        }
        XCTAssertFalse(detector.consume(angle: 112, at: 1.0))
        XCTAssertFalse(detector.consume(angle: 114, at: 1.1))
        XCTAssertFalse(detector.consume(angle: 116, at: 1.2))
    }

    func testLateReturnIsIgnored() {
        var detector = PetGestureDetector()
        XCTAssertFalse(detector.consume(angle: 110, at: 1.0))
        XCTAssertFalse(detector.consume(angle: 113, at: 1.2))
        XCTAssertFalse(detector.consume(angle: 113, at: 3.9))
        XCTAssertFalse(detector.consume(angle: 110, at: 4.0))
    }
}
