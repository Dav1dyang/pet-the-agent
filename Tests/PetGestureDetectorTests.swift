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

    func testSeparatedWigglesDoNotBecomeOnePet() {
        var detector = PetGestureDetector()
        for (time, angle) in [(0.0, 110.0), (0.2, 112.2), (0.8, 111.9),
                              (1.4, 110.1), (2.0, 110.1), (3.0, 110.1),
                              (3.8, 112.1), (4.4, 111.5), (5.0, 110.0)] {
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

    func testLongGentlePetTriggersWhileMovementContinues() {
        var detector = PetGestureDetector(excursionDegrees: 0.1)
        let samples: [(Double, Double)] = [
            (0.0, 110.00), (0.8, 110.04), (1.6, 110.11),
            (2.4, 110.16), (3.2, 110.09), (4.0, 110.02),
            (4.8, 109.97), (5.6, 109.89), (6.4, 109.95),
            (7.2, 110.02)
        ]
        for (index, sample) in samples.enumerated() {
            XCTAssertEqual(detector.consume(angle: sample.1, at: sample.0), index == 8)
        }
        XCTAssertTrue(detector.isInPet)
        XCTAssertFalse(detector.consume(angle: 110.14, at: 8.0))
        XCTAssertFalse(detector.consume(angle: 109.94, at: 8.8))
        XCTAssertFalse(detector.consume(angle: 110.03, at: 9.6))
        XCTAssertTrue(detector.isInPet)
    }

    func testContinuousPetRepeatsOnlyAfterMoreStrokesAndShortInterval() {
        var detector = PetGestureDetector(excursionDegrees: 0.1)
        var detectionTimes: [Double] = []
        for sample in 0...1200 {
            let time = Double(sample) / 60
            let angle = 110 + 0.15 * sin(time * 2 * .pi / 1.3)
            if detector.consume(angle: angle, at: time) {
                detectionTimes.append(time)
            }
        }
        XCTAssertGreaterThanOrEqual(detectionTimes.count, 3)
        for pair in zip(detectionTimes, detectionTimes.dropFirst()) {
            XCTAssertGreaterThanOrEqual(pair.1 - pair.0, 2.5)
        }
        XCTAssertTrue(detector.isInPet)
    }

    func testSlowContinuousPetRepeatsDuringTwelveSecondTest() {
        var detector = PetGestureDetector(excursionDegrees: 0.1)
        var detectionTimes: [Double] = []
        for sample in 0...720 {
            let time = Double(sample) / 60
            let angle = 110 + 0.15 * sin(time * 2 * .pi / 3)
            if detector.consume(angle: angle, at: time) {
                detectionTimes.append(time)
            }
        }
        XCTAssertGreaterThanOrEqual(detectionTimes.count, 2)
        XCTAssertGreaterThanOrEqual(detectionTimes[1] - detectionTimes[0], 2.5)
    }

    func testStillScreenDoesNotSendAnotherCompliment() {
        var detector = PetGestureDetector(excursionDegrees: 0.1)
        var detections = 0
        for sample in 0...600 {
            let time = Double(sample) / 60
            let angle = time < 3
                ? 110 + 0.15 * sin(time * 2 * .pi / 1.3)
                : 110.0
            if detector.consume(angle: angle, at: time) {
                detections += 1
            }
        }
        XCTAssertEqual(detections, 1)
        XCTAssertFalse(detector.isInPet)
    }

    func testEarlyExtraStrokeDoesNotQueueALaterSend() {
        var detector = PetGestureDetector()
        for (time, angle) in [(1.0, 110.0), (1.1, 112.1), (1.28, 110.2),
                              (1.42, 112.2)] {
            XCTAssertFalse(detector.consume(angle: angle, at: time))
        }
        XCTAssertTrue(detector.consume(angle: 110.1, at: 1.62))
        XCTAssertFalse(detector.consume(angle: 112.1, at: 1.8))
        XCTAssertFalse(detector.consume(angle: 110.1, at: 2.0))
        for sample in 21...60 {
            XCTAssertFalse(detector.consume(angle: 110.1, at: Double(sample) / 10))
        }
    }

    func testOneWayAdjustmentAfterPetDoesNotRepeat() {
        var detector = PetGestureDetector(excursionDegrees: 0.1)
        var detections = 0
        for sample in 0...540 {
            let time = Double(sample) / 60
            let angle = time < 3
                ? 110 + 0.15 * sin(time * 2 * .pi / 1.3)
                : 110 + (time - 3) * 0.8
            if detector.consume(angle: angle, at: time) {
                detections += 1
            }
        }
        XCTAssertEqual(detections, 1)
    }

    func testContinuousScreenAdjustmentDoesNotBecomePet() {
        var detector = PetGestureDetector(excursionDegrees: 0.1)
        for sample in 0...600 {
            let time = Double(sample) / 60
            let angle = 110 + time * 0.8 + 0.01 * sin(time * 17)
            XCTAssertFalse(detector.consume(angle: angle, at: time))
        }
    }

    func testContinuousPetOnlyTriggersOnceThenRearmsAfterRest() {
        var detector = PetGestureDetector()
        for (time, angle) in [(1.0, 110.0), (1.1, 112.1), (1.28, 110.2),
                              (1.42, 112.2)] {
            XCTAssertFalse(detector.consume(angle: angle, at: time))
        }
        XCTAssertTrue(detector.consume(angle: 110.1, at: 1.62))
        for (time, angle) in [(2.0, 112.1), (2.2, 110.0),
                              (2.8, 112.1), (3.0, 110.2),
                              (3.6, 112.2), (3.9, 110.1)] {
            XCTAssertFalse(detector.consume(angle: angle, at: time))
            XCTAssertTrue(detector.isInPet)
        }
        XCTAssertFalse(detector.consume(angle: 110.1, at: 4.7))
        XCTAssertFalse(detector.consume(angle: 110.1, at: 5.4))
        XCTAssertFalse(detector.isInPet)
        XCTAssertFalse(detector.consume(angle: 112.2, at: 5.6))
        XCTAssertFalse(detector.consume(angle: 110.1, at: 5.8))
        XCTAssertFalse(detector.consume(angle: 112.2, at: 6.0))
        XCTAssertTrue(detector.consume(angle: 110.1, at: 6.2))
    }
}
