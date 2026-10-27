import Foundation

/// Two small out-and-back strokes start a pet. The rest of that continuous
/// movement belongs to the same pet, even if the screen keeps moving.
struct PetGestureDetector {
    var excursionDegrees: Double = 2
    private(set) var completedWiggles = 0
    private(set) var isInPet = false

    private let maximumGestureSeconds: TimeInterval = 10
    private let trackingPauseSeconds: TimeInterval = 2.2
    private let petRestSeconds: TimeInterval = 1.5

    private var anchor: Double?
    private var origin: Double?
    private var peak: Double?
    private var direction = 0.0
    private var startedAt = 0.0
    private var lastSampleAt: TimeInterval?
    private var lastMotionAt: TimeInterval?
    private var motionReference: Double?
    private var suppressedUntil = 0.0

    mutating func reset(at angle: Double? = nil) {
        isInPet = false
        lastSampleAt = nil
        lastMotionAt = nil
        motionReference = angle
        resetTracking(at: angle)
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

        // A fresh stroke after a long still period is a new attempt, even if
        // this sample itself is the first meaningful movement.
        if !isInPet, let lastMotionAt, time - lastMotionAt > trackingPauseSeconds {
            resetTracking(at: angle)
        }

        let motionStep = max(0.025, excursionDegrees * 0.15)
        if let motionReference {
            if abs(angle - motionReference) >= motionStep {
                self.motionReference = angle
                lastMotionAt = time
            }
        } else {
            motionReference = angle
            lastMotionAt = time
        }

        if isInPet {
            if let lastMotionAt, time - lastMotionAt >= petRestSeconds {
                isInPet = false
                resetTracking(at: angle)
            }
            return false
        }

        if time < suppressedUntil { return false }
        guard let anchor else {
            self.anchor = angle
            return false
        }

        let displacement = angle - anchor
        let maximumDisplacement = max(1.5, excursionDegrees * 2.75)
        if abs(angle - (origin ?? anchor)) > maximumDisplacement ||
            ((peak != nil || completedWiggles > 0) &&
             time - startedAt > maximumGestureSeconds) {
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
            }
            return false
        }

        if direction * (angle - peak) > 0 {
            self.peak = angle
            return false
        }

        let returnDistance = direction * (peak - angle)
        let nearAnchor = abs(displacement) <= excursionDegrees * 0.9
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

        isInPet = true
        lastMotionAt = time
        motionReference = angle
        resetTracking(at: angle)
        return true
    }

    private mutating func resetTracking(at angle: Double?) {
        anchor = angle
        origin = nil
        peak = nil
        direction = 0
        completedWiggles = 0
        startedAt = 0
    }

    private mutating func rejectMovement(at angle: Double, time: TimeInterval) {
        resetTracking(at: angle)
        motionReference = angle
        lastMotionAt = time
        suppressedUntil = time + 0.2
    }
}
