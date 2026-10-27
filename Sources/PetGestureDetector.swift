import Foundation

/// Recognizes two quick, small out-and-back hinge movements near one angle.
/// A screen adjustment or a single settling bounce should not count as a pet.
struct PetGestureDetector {
    var excursionDegrees: Double = 2
    var cooldownSeconds: TimeInterval = 3

    private var anchor: Double?
    private var peak: Double?
    private var direction = 0.0
    private var completedWiggles = 0
    private var startedAt = 0.0
    private var lastSampleAt: TimeInterval?
    private var cooldownUntil = 0.0
    private var suppressedUntil = 0.0

    mutating func reset(at angle: Double? = nil) {
        anchor = angle
        peak = nil
        direction = 0
        completedWiggles = 0
        startedAt = 0
        lastSampleAt = nil
    }

    mutating func consume(angle: Double, at time: TimeInterval) -> Bool {
        guard angle.isFinite, (45...165).contains(angle), excursionDegrees > 0 else {
            reset()
            return false
        }
        if let lastSampleAt, time - lastSampleAt > 1 {
            reset(at: angle)
        }
        lastSampleAt = time

        guard time >= cooldownUntil, time >= suppressedUntil else {
            anchor = angle
            peak = nil
            completedWiggles = 0
            return false
        }
        guard let anchor else {
            self.anchor = angle
            return false
        }

        let displacement = angle - anchor
        let maximumDisplacement = excursionDegrees * 2.5
        if abs(displacement) > maximumDisplacement ||
            ((peak != nil || completedWiggles > 0) && time - startedAt > 2) {
            rejectMovement(at: angle, time: time)
            return false
        }

        guard let peak else {
            if abs(displacement) >= excursionDegrees {
                direction = displacement > 0 ? 1 : -1
                self.peak = angle
                if completedWiggles == 0 { startedAt = time }
            } else if completedWiggles == 0 && abs(displacement) < excursionDegrees * 0.25 {
                self.anchor = angle
            }
            return false
        }

        if direction * (angle - peak) > 0 {
            self.peak = angle
            return false
        }

        let returnDistance = direction * (peak - angle)
        let nearAnchor = abs(displacement) <= excursionDegrees * 0.45
        guard returnDistance >= excursionDegrees * 0.65, nearAnchor else { return false }

        completedWiggles += 1
        self.peak = nil
        direction = 0
        guard completedWiggles == 2 else { return false }
        guard time - startedAt >= 0.24 else {
            rejectMovement(at: angle, time: time)
            return false
        }

        cooldownUntil = time + cooldownSeconds
        reset(at: angle)
        lastSampleAt = time
        return true
    }

    private mutating func rejectMovement(at angle: Double, time: TimeInterval) {
        reset(at: angle)
        lastSampleAt = time
        suppressedUntil = time + 0.35
    }
}
