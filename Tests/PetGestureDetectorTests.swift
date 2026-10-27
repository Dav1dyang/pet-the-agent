import XCTest
@testable import PetTheAgent

final class PetGestureDetectorTests: XCTestCase {
    func testThreeQuickWigglesTriggerOnce() {
        var detector = PetGestureDetector()
        XCTAssertFalse(detector.consume(angle: 110, at: 1.00))
        XCTAssertFalse(detector.consume(angle: 112.1, at: 1.10))
        XCTAssertFalse(detector.consume(angle: 110.2, at: 1.28))
        XCTAssertFalse(detector.consume(angle: 112.2, at: 1.42))
        XCTAssertFalse(detector.consume(angle: 110.1, at: 1.62))
        XCTAssertFalse(detector.consume(angle: 112.1, at: 1.75))
        XCTAssertTrue(detector.consume(angle: 110.1, at: 1.90))
    }

    func testOneAdjustmentAndSettlingBounceDoNotTrigger() {
        var detector = PetGestureDetector()
        for (time, angle) in [(1.0, 110.0), (1.2, 112.2), (1.35, 110.1),
                              (1.5, 111.0), (1.65, 110.3), (1.8, 110.0)] {
            XCTAssertFalse(detector.consume(angle: angle, at: time),
                           "Unexpected pet at \(time)s, angle \(angle)°")
        }
    }

    func testUnevenStrokesDoNotStartPetButARegularRunCanRecover() {
        var detector = PetGestureDetector()
        let uneven: [(Double, Double)] = [
            (1.00, 110.0), (1.10, 112.1), (1.28, 110.1),
            (1.42, 112.1), (1.62, 110.1),
            (2.70, 112.1), (2.85, 110.1)
        ]
        for (time, angle) in uneven {
            XCTAssertFalse(detector.consume(angle: angle, at: time))
        }
        XCTAssertFalse(detector.consume(angle: 112.1, at: 3.00))
        XCTAssertFalse(detector.consume(angle: 110.1, at: 3.20))
        XCTAssertFalse(detector.consume(angle: 112.1, at: 3.36))
        XCTAssertTrue(detector.consume(angle: 110.1, at: 3.56))
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
        XCTAssertFalse(detector.consume(angle: 110.12, at: 1.90))
        XCTAssertFalse(detector.consume(angle: 111.15, at: 2.12))
        XCTAssertTrue(detector.consume(angle: 110.10, at: 2.35))
    }

    func testGentleWigglesHaveTimeToComplete() {
        var detector = PetGestureDetector()
        XCTAssertFalse(detector.consume(angle: 110.0, at: 0.0))
        XCTAssertFalse(detector.consume(angle: 112.5, at: 0.4))
        XCTAssertFalse(detector.consume(angle: 110.4, at: 1.0))
        XCTAssertEqual(detector.completedWiggles, 1)
        XCTAssertFalse(detector.consume(angle: 112.8, at: 1.8))
        XCTAssertFalse(detector.consume(angle: 110.6, at: 2.5))
        XCTAssertFalse(detector.consume(angle: 112.7, at: 3.2))
        XCTAssertTrue(detector.consume(angle: 110.7, at: 4.0))
    }

    func testTenthDegreePetTriggersWithPreciseReadings() {
        var detector = PetGestureDetector(excursionDegrees: 0.1)
        XCTAssertFalse(detector.consume(angle: 110.00, at: 1.00))
        XCTAssertFalse(detector.consume(angle: 110.12, at: 1.10))
        XCTAssertFalse(detector.consume(angle: 110.02, at: 1.25))
        XCTAssertFalse(detector.consume(angle: 109.88, at: 1.35))
        XCTAssertFalse(detector.consume(angle: 110.01, at: 1.55))
        XCTAssertFalse(detector.consume(angle: 110.13, at: 1.70))
        XCTAssertTrue(detector.consume(angle: 110.01, at: 1.90))
    }

    func testSubThresholdJitterDoesNotTrigger() {
        var detector = PetGestureDetector(excursionDegrees: 0.1)
        for (index, angle) in [110.00, 110.02, 109.98, 110.04, 109.97,
                               110.01, 110.05, 109.99].enumerated() {
            XCTAssertFalse(detector.consume(angle: angle, at: Double(index) * 0.1))
        }
    }

    func testSteadyPetTriggersWhileMovementContinues() {
        var detector = PetGestureDetector(excursionDegrees: 0.1)
        var detections: [Double] = []
        for sample in 0...480 {
            let time = Double(sample) / 60
            let angle = 110 + 0.04 * time +
                0.15 * sin(time * 2 * .pi / 1.5)
            if detector.consume(angle: angle, at: time) {
                detections.append(time)
            }
        }
        XCTAssertGreaterThanOrEqual(detections.count, 1)
        XCTAssertLessThan(detections.first ?? 100, 6)
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

    func testDriftingBaselineStillProducesRepeatedPets() {
        var detector = PetGestureDetector(excursionDegrees: 0.1)
        var detectionTimes: [Double] = []
        for sample in 0...1200 {
            let time = Double(sample) / 60
            let driftingCenter = 110 + 0.045 * time
            let angle = driftingCenter + 0.14 * sin(time * 2 * .pi / 1.6)
            if detector.consume(angle: angle, at: time) {
                detectionTimes.append(time)
            }
        }
        XCTAssertGreaterThanOrEqual(detectionTimes.count, 3)
        for pair in zip(detectionTimes, detectionTimes.dropFirst()) {
            XCTAssertGreaterThanOrEqual(pair.1 - pair.0, 2.5)
        }
    }

    func testDriftingPetWithSmallSensorJitterStillWorks() {
        var detector = PetGestureDetector(excursionDegrees: 0.1)
        var detections = 0
        for sample in 0...900 {
            let time = Double(sample) / 60
            let jitter = 0.008 * sin(time * 83) + 0.005 * sin(time * 47)
            let angle = 110 + 0.035 * time +
                0.13 * sin(time * 2 * .pi / 1.5) + jitter
            if detector.consume(angle: angle, at: time) { detections += 1 }
        }
        XCTAssertGreaterThanOrEqual(detections, 2)
    }

    func testFasterBaselineShiftStillFeelsLikePetting() {
        for driftPerSecond in [0.08, 0.12] {
            var detector = PetGestureDetector(excursionDegrees: 0.1)
            var detections = 0
            for sample in 0...900 {
                let time = Double(sample) / 60
                let angle = 110 + driftPerSecond * time +
                    0.15 * sin(time * 2 * .pi / 1.6)
                if detector.consume(angle: angle, at: time) { detections += 1 }
            }
            XCTAssertGreaterThanOrEqual(detections, 2, "Drift: \(driftPerSecond)°/s")
        }
    }

    func testBaselineFollowsAnUnpettedScreenAdjustment() {
        var detector = PetGestureDetector(excursionDegrees: 0.1)
        for sample in 0...600 {
            let time = Double(sample) / 60
            let angle = 110 + 0.12 * time
            XCTAssertFalse(detector.consume(angle: angle, at: time))
        }
        XCTAssertEqual(detector.baselineDegrees ?? 0, 111.2, accuracy: 0.07)
    }

    func testBaselineSettlesAfterScreenIsRepositioned() {
        var detector = PetGestureDetector(excursionDegrees: 0.1)
        for sample in 0...300 {
            let time = Double(sample) / 60
            let angle = time < 1 ? 110.0 : 111.0
            XCTAssertFalse(detector.consume(angle: angle, at: time))
        }
        XCTAssertEqual(detector.baselineDegrees ?? 0, 111.0, accuracy: 0.02)
    }

    func testScreenAdjustmentWithDampedBounceDoesNotCount() {
        var detector = PetGestureDetector(excursionDegrees: 0.1)
        for sample in 0...360 {
            let time = Double(sample) / 60
            let angle: Double
            if time < 1 {
                angle = 110 + 0.7 * time
            } else {
                let settledTime = time - 1
                angle = 110.7 + 0.18 * exp(-2 * settledTime) *
                    sin(settledTime * 2 * .pi / 0.45)
            }
            XCTAssertFalse(detector.consume(angle: angle, at: time),
                           "Unexpected pet at \(time)s, angle \(angle)°")
        }
    }

    func testPettingSurvivesSmallCenterShiftsEachStroke() {
        var detector = PetGestureDetector(excursionDegrees: 0.1)
        var detections = 0
        for sample in 0...900 {
            let time = Double(sample) / 60
            let phase = time.truncatingRemainder(dividingBy: 1.6)
            let cycles = floor(time / 1.6)
            let center = 110 + 0.10 * cycles + 0.10 * min(phase / 0.4, 1)
            let angle = center + 0.15 * sin(time * 2 * .pi / 1.6)
            if detector.consume(angle: angle, at: time) { detections += 1 }
        }
        XCTAssertGreaterThanOrEqual(detections, 2)
    }

    func testPetsAcrossPaceDriftAndJitter() {
        let cases: [(amplitude: Double, period: Double, drift: Double)] = [
            (0.13, 1.2, 0.10),
            (0.15, 1.6, 0.12),
            (0.15, 2.0, 0.07),
            (0.18, 2.4, 0.06),
            (0.20, 1.8, 0.04)
        ]
        for scenario in cases {
            var detector = PetGestureDetector(excursionDegrees: 0.1)
            var detectionTimes: [Double] = []
            for sample in 0...1200 {
                let time = Double(sample) / 60
                let jitter = 0.006 * sin(time * 71) + 0.004 * sin(time * 113)
                let angle = 110 + scenario.drift * time +
                    scenario.amplitude * sin(time * 2 * .pi / scenario.period) +
                    jitter
                if detector.consume(angle: angle, at: time) {
                    detectionTimes.append(time)
                }
            }
            XCTAssertGreaterThanOrEqual(
                detectionTimes.count, 2,
                "Amplitude \(scenario.amplitude), period \(scenario.period), drift \(scenario.drift)"
            )
            if detectionTimes.count >= 2 {
                XCTAssertGreaterThanOrEqual(detectionTimes[1] - detectionTimes[0], 2.5)
            }
        }
    }

    func testOneWayAdjustmentsWithJitterNeverPet() {
        for slope in [-0.2, 0.0, 0.05, 0.2, 0.8] {
            for noise in [0.005, 0.02, 0.04] {
                var detector = PetGestureDetector(excursionDegrees: 0.1)
                var detections = 0
                for sample in 0...1200 {
                    let time = Double(sample) / 60
                    let jitter = noise * sin(time * 23) +
                        noise * 0.5 * sin(time * 41)
                    let angle = 110 + slope * time + jitter
                    if detector.consume(angle: angle, at: time) {
                        detections += 1
                    }
                }
                XCTAssertEqual(detections, 0, "Slope \(slope), noise \(noise)")
            }
        }
    }

    func testTimeBasedFiltersBehaveAcrossPollingRates() {
        var firstPetTimes: [Double] = []
        for samplesPerSecond in [30, 60, 120] {
            var detector = PetGestureDetector(excursionDegrees: 0.1)
            var firstPetAt: Double?
            for sample in 0...(12 * samplesPerSecond) {
                let time = Double(sample) / Double(samplesPerSecond)
                let angle = 110 + 0.08 * time +
                    0.15 * sin(time * 2 * .pi / 1.6)
                if detector.consume(angle: angle, at: time), firstPetAt == nil {
                    firstPetAt = time
                }
            }
            if let firstPetAt { firstPetTimes.append(firstPetAt) }
        }
        XCTAssertEqual(firstPetTimes.count, 3)
        if firstPetTimes.count == 3 {
            XCTAssertLessThan(firstPetTimes.max()! - firstPetTimes.min()!, 0.2)
        }
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
        XCTAssertFalse(detector.consume(angle: 110.1, at: 1.62))
        XCTAssertFalse(detector.consume(angle: 112.1, at: 1.8))
        XCTAssertTrue(detector.consume(angle: 110.1, at: 2.0))
        XCTAssertFalse(detector.consume(angle: 112.1, at: 2.15))
        XCTAssertFalse(detector.consume(angle: 110.1, at: 2.35))
        for sample in 24...60 {
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
        var detector = PetGestureDetector(excursionDegrees: 0.1)
        var detections: [Double] = []
        for sample in 0...720 {
            let time = Double(sample) / 60
            let angle: Double
            if time < 3.8 {
                angle = 110 + 0.15 * sin(time * 2 * .pi / 0.9)
            } else if time < 6 {
                angle = 110
            } else {
                angle = 110 + 0.15 * sin((time - 6) * 2 * .pi / 0.9)
            }
            if detector.consume(angle: angle, at: time) { detections.append(time) }
        }
        XCTAssertGreaterThanOrEqual(detections.filter { $0 < 6 }.count, 1)
        XCTAssertGreaterThanOrEqual(detections.filter { $0 >= 6 }.count, 1)
        XCTAssertLessThan(detections.filter { $0 >= 6 }.first ?? 100, 9)
    }
}
