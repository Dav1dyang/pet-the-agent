import Foundation

/// Detects a short burst of acceleration followed by a return to rest.
struct MotionPulseDetector {
    var thresholdG = 0.03
    var cooldownSeconds: TimeInterval = 15

    private var startedAt: TimeInterval?
    private var peakG = 0.0
    private var cooldownUntil = 0.0

    mutating func reset() {
        startedAt = nil
        peakG = 0
    }

    mutating func consume(activityG: Double, at time: TimeInterval) -> Bool {
        guard activityG.isFinite, activityG >= 0 else {
            reset()
            return false
        }
        guard time >= cooldownUntil else { return false }

        guard let startedAt else {
            if activityG >= thresholdG {
                self.startedAt = time
                peakG = activityG
            }
            return false
        }

        if time - startedAt > 1.5 {
            reset()
            return false
        }
        peakG = max(peakG, activityG)
        if activityG < thresholdG * 0.4 {
            let wasPet = time - startedAt >= 0.08 && peakG >= thresholdG
            reset()
            if wasPet { cooldownUntil = time + cooldownSeconds }
            return wasPet
        }
        return false
    }
}
