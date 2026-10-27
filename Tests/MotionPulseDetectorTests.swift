import XCTest
@testable import PetTheAgent

final class MotionPulseDetectorTests: XCTestCase {
    func testSustainedMotionThenRestTriggers() {
        var detector = MotionPulseDetector()
        XCTAssertFalse(detector.consume(activityG: 0.005, at: 1.00))
        XCTAssertFalse(detector.consume(activityG: 0.04, at: 1.10))
        XCTAssertFalse(detector.consume(activityG: 0.05, at: 1.20))
        XCTAssertTrue(detector.consume(activityG: 0.008, at: 1.30))
        XCTAssertFalse(detector.consume(activityG: 0.05, at: 1.40))
        XCTAssertFalse(detector.consume(activityG: 0.005, at: 1.50))
    }

    func testBriefSpikeDoesNotTrigger() {
        var detector = MotionPulseDetector()
        XCTAssertFalse(detector.consume(activityG: 0.05, at: 1.00))
        XCTAssertFalse(detector.consume(activityG: 0.002, at: 1.02))
    }
}
