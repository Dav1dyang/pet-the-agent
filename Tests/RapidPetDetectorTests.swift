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
