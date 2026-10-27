import Foundation

/// Recognizes two quick, small out-and-back hinge movements near one angle.
/// A screen adjustment or a single settling bounce should not count as a pet.
struct PetGestureDetector {
    var excursionDegrees: Double = 2
    var cooldownSeconds: TimeInterval = 1

    private var anchor: Double?
    private var origin: Double?
    private var peak: Double?
    private var direction = 0.0
    private(set) var completedWiggles = 0
    private var startedAt = 0.0
    private var lastSampleAt: TimeInterval?
    private var cooldownUntil = 0.0
    private var suppressedUntil = 0.0

    mutating func reset(at angle: Double? = nil) {
        anchor = angle
        origin = nil
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
        if let lastSampleAt, time - lastSampleAt > 1.5 {
            reset(at: angle)
        }
        lastSampleAt = time

        guard time >= cooldownUntil, time >= suppressedUntil else {
            reset(at: angle)
            lastSampleAt = time
            return false
        }
        guard let anchor else {
            self.anchor = angle
            return false
        }

        let displacement = angle - anchor
        let maximumDisplacement = max(1.5, excursionDegrees * 2.75)
        if abs(angle - (origin ?? anchor)) > maximumDisplacement ||
            ((peak != nil || completedWiggles > 0) && time - startedAt > 3) {
            rejectMovement(at: angle, time: time)
            return false
        }

        guard let peak else {
            if abs(displacement) >= excursionDegrees {
                direction = displacement > 0 ? 1 : -1
                self.peak = angle
                if completedWiggles == 0 {
                    startedAt = time
                    origin = anchor
                }
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
        let nearAnchor = abs(displacement) <= excursionDegrees * 0.85
        guard returnDistance >= excursionDegrees * 0.6, nearAnchor else { return false }

        completedWiggles += 1
        self.peak = nil
        direction = 0
        guard completedWiggles == 2 else {
            self.anchor = angle
            return false
        }
        guard time - startedAt >= 0.18 else {
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
        suppressedUntil = time + 0.2
    }
}
