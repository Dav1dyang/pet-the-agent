import XCTest
@testable import PetTheAgent

final class HingeRecordingTests: XCTestCase {
    func testSteadyPetWithDriftingCenterCanCalibrate() {
        let samples = (0...900).map { index -> HingeSample in
            let time = Double(index) / 60
            let angle = 110 + 0.08 * time +
                0.16 * sin(time * 2 * .pi / 1.2) +
                0.006 * sin(time * 63)
            return HingeSample(seconds: time, angle: angle,
                               baseline: 110 + 0.08 * time, petEvent: false)
        }
        let result = HingeRecording.calibration(from: samples, minimumDistance: 0.1)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.strokePeriod ?? 0, 1.2, accuracy: 0.1)
        XCTAssertEqual(result?.suggestedDistance, 0.1)
        XCTAssertGreaterThanOrEqual(result?.strokeCount ?? 0, 5)
    }

    func testQuietSensorNoiseAndOneWayAdjustmentHaveNoCalibration() {
        for slope in [0.0, 0.8] {
            let samples = (0...900).map { index -> HingeSample in
                let time = Double(index) / 60
                let angle = 110 + slope * time + 0.02 * sin(time * 41)
                return HingeSample(seconds: time, angle: angle,
                                   baseline: 110, petEvent: false)
            }
            XCTAssertNil(HingeRecording.calibration(from: samples, minimumDistance: 0.1))
        }
    }

    func testCSVKeepsSamplesAndDetectedEvents() {
        let samples = [
            HingeSample(seconds: 0, angle: 110.1, baseline: 110.0, petEvent: false),
            HingeSample(seconds: 0.1, angle: 110.2, baseline: 110.1, petEvent: true)
        ]
        let csv = HingeRecording.csv(samples)
        XCTAssertTrue(csv.contains("time_seconds,angle_degrees,baseline_degrees,delta_degrees,pet_event"))
        XCTAssertTrue(csv.contains("0.100,110.2000,110.1000,0.1000,1"))
    }
}
