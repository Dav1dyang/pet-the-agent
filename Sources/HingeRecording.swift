import Foundation

struct HingeSample {
    let seconds: Double
    let angle: Double
    let baseline: Double
    let petEvent: Bool
}

struct HingeCalibration: Equatable {
    let suggestedDistance: Double
    let strokePeriod: Double
    let swingDegrees: Double
    let strokeCount: Int
}

enum HingeRecording {
    static func calibration(
        from samples: [HingeSample],
        minimumDistance: Double
    ) -> HingeCalibration? {
        guard samples.count >= 60 else { return nil }

        if minimumDistance < 1,
           let rapid = rapidCalibration(from: samples) {
            return rapid
        }

        // Find real turning points in a lightly smoothed trace. Hysteresis
        // keeps sensor quantization and tiny jitter from becoming strokes.
        let turnDistance = max(0.06, minimumDistance * 0.6)
        var filtered = samples[0].angle
        var previousTime = samples[0].seconds
        var direction = 0
        var extreme = filtered
        var extremeTime = previousTime
        var turns: [(time: Double, angle: Double)] = []

        for sample in samples.dropFirst() {
            let interval = sample.seconds - previousTime
            guard interval > 0, interval < 0.5, sample.angle.isFinite else { continue }
            previousTime = sample.seconds
            let weight = 1 - exp(-interval / 0.06)
            filtered += weight * (sample.angle - filtered)

            if direction == 0 {
                if filtered >= extreme + turnDistance {
                    direction = 1
                    extreme = filtered
                    extremeTime = sample.seconds
                } else if filtered <= extreme - turnDistance {
                    direction = -1
                    extreme = filtered
                    extremeTime = sample.seconds
                }
            } else if direction > 0 {
                if filtered > extreme {
                    extreme = filtered
                    extremeTime = sample.seconds
                } else if extreme - filtered >= turnDistance {
                    turns.append((extremeTime, extreme))
                    direction = -1
                    extreme = filtered
                    extremeTime = sample.seconds
                }
            } else {
                if filtered < extreme {
                    extreme = filtered
                    extremeTime = sample.seconds
                } else if filtered - extreme >= turnDistance {
                    turns.append((extremeTime, extreme))
                    direction = 1
                    extreme = filtered
                    extremeTime = sample.seconds
                }
            }
        }

        guard turns.count >= 7 else { return nil }
        let periods = (2..<turns.count).map { turns[$0].time - turns[$0 - 2].time }
            .filter { (0.5...3.2).contains($0) }
        guard periods.count >= 5 else { return nil }
        let period = median(periods)
        let deviations = periods.map { abs($0 - period) }
        guard median(deviations) / period <= 0.28 else { return nil }

        let swings = (1..<turns.count).map { abs(turns[$0].angle - turns[$0 - 1].angle) }
            .filter { $0 >= turnDistance * 1.8 }
        guard swings.count >= 6 else { return nil }
        let swing = median(swings)
        let step = minimumDistance < 1 ? 0.1 : 1.0
        let suggestion = min(5, max(minimumDistance, (swing * 0.45 / step).rounded() * step))
        return HingeCalibration(
            suggestedDistance: suggestion,
            strokePeriod: period,
            swingDegrees: swing,
            strokeCount: periods.count
        )
    }

    private static func rapidCalibration(from samples: [HingeSample]) -> HingeCalibration? {
        let duration = (samples.last?.seconds ?? 0) - (samples.first?.seconds ?? 0)
        guard duration >= 5 else { return nil }
        let requiredEvents = duration >= 10 ? 3 : 2
        var best: HingeCalibration?
        for distance in [0.02, 0.03, 0.04, 0.05, 0.06, 0.08] {
            var detector = RapidPetDetector(distanceDegrees: distance)
            var periods: [Double] = []
            var swings: [Double] = []
            for sample in samples {
                if detector.consume(angle: sample.angle, at: sample.seconds),
                   let period = detector.observedCycleSeconds,
                   let swing = detector.observedSwingDegrees {
                    periods.append(period)
                    swings.append(swing)
                }
            }
            guard periods.count >= requiredEvents else { continue }
            if best == nil || periods.count > best!.strokeCount ||
                (periods.count == best!.strokeCount && distance > best!.suggestedDistance) {
                best = HingeCalibration(
                    suggestedDistance: distance,
                    strokePeriod: median(periods),
                    swingDegrees: median(swings),
                    strokeCount: periods.count
                )
            }
        }
        return best
    }

    static func csv(_ samples: [HingeSample]) -> String {
        var lines = ["time_seconds,angle_degrees,baseline_degrees,delta_degrees,pet_event"]
        lines.reserveCapacity(samples.count + 1)
        for sample in samples {
            lines.append(String(
                format: "%.3f,%.4f,%.4f,%.4f,%d",
                locale: Locale(identifier: "en_US_POSIX"),
                arguments: [sample.seconds, sample.angle, sample.baseline,
                            sample.angle - sample.baseline, sample.petEvent ? 1 : 0]
            ))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        let middle = sorted.count / 2
        return sorted.count.isMultiple(of: 2)
            ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
    }
}
