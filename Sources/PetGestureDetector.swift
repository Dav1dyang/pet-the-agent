import Foundation

/// Recognizes one small out-and-back lid movement. Times are monotonic seconds.
struct PetGestureDetector {
    var excursionDegrees: Double = 2
    var cooldownSeconds: TimeInterval = 3

    private var anchor: Double?
    private var peak: Double?
    private var direction = 0.0
    private var startedAt = 0.0
    private var lastSampleAt: TimeInterval?
    private var cooldownUntil = 0.0

    mutating func reset(at angle: Double? = nil) {
        anchor = angle
        peak = nil
        direction = 0
        lastSampleAt = nil
    }

    mutating func consume(angle: Double, at time: TimeInterval) -> Bool {
        guard (45...165).contains(angle) else {
            reset()
            return false
        }
        if let lastSampleAt, time - lastSampleAt > 1 {
            reset(at: angle)
        }
        lastSampleAt = time

        guard time >= cooldownUntil else {
            anchor = angle
            peak = nil
            return false
        }
        guard let anchor else {
            self.anchor = angle
            return false
        }

        if let peak {
            if time - startedAt > 2.5 || abs(angle - anchor) > 12 {
                reset(at: angle)
                lastSampleAt = time
                return false
            }
            if direction * (angle - peak) > 0 {
                self.peak = angle
                return false
            }
            let returnDistance = direction * (peak - angle)
            let closeToStart = abs(angle - anchor) <= excursionDegrees * 0.8
            if time - startedAt >= 0.08,
               returnDistance >= excursionDegrees * 0.6,
               closeToStart {
                cooldownUntil = time + cooldownSeconds
                reset(at: angle)
                lastSampleAt = time
                return true
            }
            return false
        }

        let movement = angle - anchor
        if abs(movement) >= excursionDegrees {
            direction = movement > 0 ? 1 : -1
            self.peak = angle
            startedAt = time
        } else if abs(movement) < excursionDegrees * 0.25 {
            self.anchor = angle
        }
        return false
    }
}
