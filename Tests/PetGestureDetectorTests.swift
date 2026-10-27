import XCTest
@testable import PetTheAgent

final class PetGestureDetectorTests: XCTestCase {
    func testTwoSmallWigglesTriggerOnce() {
        var detector = PetGestureDetector()
        XCTAssertFalse(detector.consume(angle: 110, at: 1.00))
        XCTAssertFalse(detector.consume(angle: 112.1, at: 1.10))
        XCTAssertFalse(detector.consume(angle: 110.2, at: 1.28))
        XCTAssertFalse(detector.consume(angle: 112.2, at: 1.42))
        XCTAssertTrue(detector.consume(angle: 110.1, at: 1.62))
        XCTAssertFalse(detector.consume(angle: 112.1, at: 1.75))
        XCTAssertFalse(detector.consume(angle: 110.1, at: 1.90))
    }

    func testOneAdjustmentAndSettlingBounceDoNotTrigger() {
        var detector = PetGestureDetector()
        for (time, angle) in [(1.0, 110.0), (1.2, 112.2), (1.35, 110.1),
                              (1.5, 111.0), (1.65, 110.3), (1.8, 110.0)] {
            XCTAssertFalse(detector.consume(angle: angle, at: time))
        }
    }

    func testLargeScreenAdjustmentDoesNotTrigger() {
        var detector = PetGestureDetector(excursionDegrees: 0.1)
        for (index, angle) in [110.0, 110.1, 110.2, 110.6, 111.0, 112.0,
                               112.1, 112.0, 112.2, 112.0].enumerated() {
            XCTAssertFalse(detector.consume(angle: angle, at: Double(index) * 0.1))
        }
    }

    func testWideSecondStrokeCancelsThePet() {
        var detector = PetGestureDetector()
        for (time, angle) in [(1.0, 110.0), (1.1, 112.1), (1.28, 110.2),
                              (1.4, 116.0), (1.6, 110.0)] {
            XCTAssertFalse(detector.consume(angle: angle, at: time))
        }
    }

    func testSlowWigglesDoNotTrigger() {
        var detector = PetGestureDetector()
        for (time, angle) in [(0.0, 110.0), (0.2, 112.2), (0.8, 111.9),
                              (1.4, 110.1), (2.1, 112.1), (2.8, 111.5),
                              (3.3, 110.0)] {
            XCTAssertFalse(detector.consume(angle: angle, at: time))
        }
    }

    func testOvershootAndImperfectReturnStillCount() {
        var detector = PetGestureDetector(excursionDegrees: 0.1)
        XCTAssertFalse(detector.consume(angle: 110.00, at: 1.00))
        XCTAssertFalse(detector.consume(angle: 111.20, at: 1.15))
        XCTAssertFalse(detector.consume(angle: 110.07, at: 1.35))
        XCTAssertEqual(detector.completedWiggles, 1)
        XCTAssertFalse(detector.consume(angle: 109.32, at: 1.65))
        XCTAssertTrue(detector.consume(angle: 110.12, at: 1.90))
    }

    func testGentleWigglesHaveTimeToComplete() {
        var detector = PetGestureDetector()
        XCTAssertFalse(detector.consume(angle: 110.0, at: 0.0))
        XCTAssertFalse(detector.consume(angle: 112.5, at: 0.4))
        XCTAssertFalse(detector.consume(angle: 110.4, at: 1.0))
        XCTAssertEqual(detector.completedWiggles, 1)
        XCTAssertFalse(detector.consume(angle: 112.8, at: 1.8))
        XCTAssertTrue(detector.consume(angle: 110.6, at: 2.5))
    }

    func testTenthDegreePetTriggersWithPreciseReadings() {
        var detector = PetGestureDetector(excursionDegrees: 0.1)
        XCTAssertFalse(detector.consume(angle: 110.00, at: 1.00))
        XCTAssertFalse(detector.consume(angle: 110.12, at: 1.10))
        XCTAssertFalse(detector.consume(angle: 110.02, at: 1.25))
        XCTAssertFalse(detector.consume(angle: 109.88, at: 1.35))
        XCTAssertTrue(detector.consume(angle: 110.01, at: 1.55))
    }

    func testSubThresholdJitterDoesNotTrigger() {
        var detector = PetGestureDetector(excursionDegrees: 0.1)
        for (index, angle) in [110.00, 110.02, 109.98, 110.04, 109.97,
                               110.01, 110.05, 109.99].enumerated() {
            XCTAssertFalse(detector.consume(angle: angle, at: Double(index) * 0.1))
        }
    }

    func testAnotherPetWorksAfterShortCooldown() {
        var detector = PetGestureDetector()
        for (time, angle) in [(1.0, 110.0), (1.1, 112.1), (1.28, 110.2),
                              (1.42, 112.2)] {
            XCTAssertFalse(detector.consume(angle: angle, at: time))
        }
        XCTAssertTrue(detector.consume(angle: 110.1, at: 1.62))
        XCTAssertFalse(detector.consume(angle: 112.1, at: 2.0))
        XCTAssertFalse(detector.consume(angle: 110.0, at: 2.2))
        XCTAssertFalse(detector.consume(angle: 110.0, at: 2.7))
        XCTAssertFalse(detector.consume(angle: 112.1, at: 2.8))
        XCTAssertFalse(detector.consume(angle: 110.2, at: 3.0))
        XCTAssertFalse(detector.consume(angle: 112.2, at: 3.15))
        XCTAssertTrue(detector.consume(angle: 110.1, at: 3.35))
    }
}
