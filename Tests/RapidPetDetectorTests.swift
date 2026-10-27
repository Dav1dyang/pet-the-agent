import XCTest
@testable import PetTheAgent

final class RapidPetDetectorTests: XCTestCase {
    func testFastTinyPetRepeatsWhileMoving() {
        var detector = RapidPetDetector(distanceDegrees: 0.03)
        var events: [Double] = []
        for sample in 0...900 {
            let time = Double(sample) / 60
            let angle = 110 + 0.03 * time +
                0.05 * sin(time * 2 * .pi / 0.35)
            if detector.consume(angle: angle, at: time) { events.append(time) }
        }
        XCTAssertGreaterThanOrEqual(events.count, 4)
        XCTAssertLessThan(events.first ?? 100, 2)
        for pair in zip(events, events.dropFirst()) {
            XCTAssertGreaterThanOrEqual(pair.1 - pair.0, 2.5)
        }
        XCTAssertEqual(detector.observedCycleSeconds ?? 0, 0.35, accuracy: 0.1)
    }

    func testSmallSteppedPetSurvivesScreenRepositioning() {
        var detector = RapidPetDetector(distanceDegrees: 0.03)
        var events: [Double] = []
        for sample in 0...900 {
            let time = Double(sample) / 60
            let reposition = min(1.3, max(0, time - 2) * 1.3)
            let raw = 110 + reposition + 0.01 * time +
                0.05 * sin(time * 2 * .pi / 0.4)
            let angle = (raw * 100).rounded() / 100
            if detector.consume(angle: angle, at: time) { events.append(time) }
        }
        XCTAssertGreaterThanOrEqual(events.count, 3)
        XCTAssertTrue(events.contains { $0 < 2 })
        XCTAssertTrue(events.contains { $0 > 5 })
    }

    func testLargeCenterChangesDoNotHideLaterPetting() {
        var detector = RapidPetDetector(distanceDegrees: 0.02)
        var events: [Double] = []
        for sample in 0...900 {
            let time = Double(sample) / 60
            let firstMove = 11 * min(1, max(0, (time - 5.5) / 0.6))
            let secondMove = 9 * min(1, max(0, (time - 12) / 0.5))
            let raw = 110 + firstMove + secondMove +
                0.05 * sin(time * 2 * .pi / 0.35)
            let angle = (raw * 100).rounded() / 100
            if detector.consume(angle: angle, at: time) { events.append(time) }
        }
        XCTAssertTrue(events.contains { $0 < 3 })
        XCTAssertTrue(events.contains { $0 > 7 && $0 < 12 })
        XCTAssertTrue(events.contains { $0 > 13 })
        XCTAssertFalse(events.contains { (5.5...6.1).contains($0) })
        XCTAssertFalse(events.contains { (12...12.5).contains($0) })
    }

    func testLargeAdjustmentsAloneDoNotBecomePetsOrCalibration() {
        var detector = RapidPetDetector(distanceDegrees: 0.02)
        var samples: [HingeSample] = []
        for sample in 0...900 {
            let time = Double(sample) / 60
            let firstMove = 11 * min(1, max(0, (time - 5.5) / 0.6))
            let secondMove = 9 * min(1, max(0, (time - 12) / 0.5))
            let angle = 110 + firstMove + secondMove + 0.01 * sin(time * 19)
            XCTAssertFalse(detector.consume(angle: angle, at: time))
            samples.append(HingeSample(seconds: time, angle: angle,
                                       baseline: angle, petEvent: false))
        }
        XCTAssertNil(HingeRecording.calibration(from: samples, minimumDistance: 0.02))
    }

    func testSettlingBounceAfterPetDoesNotSendAnotherLine() {
        var detector = RapidPetDetector(distanceDegrees: 0.03)
        var events: [Double] = []
        for sample in 0...900 {
            let time = Double(sample) / 60
            let angle: Double
            if time < 3 {
                angle = 110 + 0.05 * sin(time * 2 * .pi / 0.35)
            } else {
                let settling = time - 3
                angle = 111 + 0.3 * exp(-2 * settling) *
                    sin(settling * 2 * .pi / 0.45)
            }
            if detector.consume(angle: angle, at: time) { events.append(time) }
        }
        XCTAssertEqual(events.count, 1)
    }

    func testAdjustmentBounceAndNoiseStayQuiet() {
        for scenario in 0..<4 {
            var detector = RapidPetDetector(distanceDegrees: 0.03)
            for sample in 0...900 {
                let time = Double(sample) / 60
                let angle: Double
                switch scenario {
                case 0:
                    angle = 110 + 0.8 * time + 0.01 * sin(time * 17)
                case 1:
                    if time < 1 {
                        angle = 110 + 0.7 * time
                    } else {
                        let settled = time - 1
                        angle = 110.7 + 0.18 * exp(-2 * settled) *
                            sin(settled * 2 * .pi / 0.45)
                    }
                case 2:
                    angle = 110 + 0.02 * sin(time * 41)
                default:
                    angle = 110
                }
                XCTAssertFalse(detector.consume(angle: angle, at: time))
            }
        }
    }

    func testRecordingSuggestsDistanceForTinyFastPet() {
        let samples = (0...900).map { index -> HingeSample in
            let time = Double(index) / 60
            let angle = 110 + 0.04 * sin(time * 2 * .pi / 0.4) +
                0.008 * sin(time * 49)
            return HingeSample(seconds: time, angle: angle,
                               baseline: 110, petEvent: false)
        }
        let calibration = HingeRecording.calibration(
            from: samples, minimumDistance: 0.02
        )
        XCTAssertNotNil(calibration)
        XCTAssertLessThan(calibration?.suggestedDistance ?? 1, 0.1)
        XCTAssertEqual(calibration?.strokePeriod ?? 0, 0.4, accuracy: 0.1)
    }
}
