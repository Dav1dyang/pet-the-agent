import Foundation

/// Two small out-and-back strokes start a pet. Further strokes can earn
/// another compliment after a short interval while the movement continues.
struct PetGestureDetector {
    var excursionDegrees: Double = 2
    private(set) var completedWiggles = 0
    private(set) var isInPet = false

    private let maximumGestureSeconds: TimeInterval = 10
    private let trackingPauseSeconds: TimeInterval = 2.2
    private let petRestSeconds: TimeInterval = 1.5
    private let repeatIntervalSeconds: TimeInterval = 2.5
    private var inputResponseSeconds: TimeInterval {
        excursionDegrees <= 0.25 ? 0.05 : 0.025
    }
    private let baselineResponseSeconds: TimeInterval = 0.45
    private let minimumReversalSeconds: TimeInterval = 0.12

    private var anchor: Double?
    private var origin: Double?
    private var peak: Double?
    private var peakAt = 0.0
    private var direction = 0.0
    private var startedAt = 0.0
    private var firstWiggleExcursion = 0.0
    private var lastSampleAt: TimeInterval?
    private var lastMotionAt: TimeInterval?
    private var motionReference: Double?
    private var filteredInputDegrees: Double?
    private(set) var baselineDegrees: Double?
    private var suppressedUntil = 0.0
    private var lastTriggerAt: TimeInterval?

    mutating func reset(at angle: Double? = nil) {
        isInPet = false
        lastSampleAt = nil
        lastMotionAt = nil
        motionReference = angle
        filteredInputDegrees = angle
        baselineDegrees = angle
        lastTriggerAt = nil
        resetTracking(at: angle)
    }

    mutating func consume(angle: Double, at time: TimeInterval) -> Bool {
        guard angle.isFinite, (45...165).contains(angle), excursionDegrees > 0 else {
            reset()
            return false
        }

        let sampleInterval = lastSampleAt.map { time - $0 }
        if let sampleInterval, sampleInterval > 1.5 {
            reset(at: angle)
        }
        lastSampleAt = time

        // Fast input minus slow baseline follows the user's two-filter design.
        // Time-based gains give the same behavior if the polling rate varies.
        if let filteredInputDegrees, let baselineDegrees,
           let sampleInterval, sampleInterval > 0 {
            let inputWeight = 1 - exp(-sampleInterval / inputResponseSeconds)
            let baselineWeight = 1 - exp(-sampleInterval / baselineResponseSeconds)
            self.filteredInputDegrees = filteredInputDegrees +
                inputWeight * (angle - filteredInputDegrees)
            self.baselineDegrees = baselineDegrees +
                baselineWeight * (angle - baselineDegrees)
        } else {
            filteredInputDegrees = angle
            baselineDegrees = angle
        }
        let inputAngle = filteredInputDegrees ?? angle

        // A fresh stroke after a long still period is a new attempt, even if
        // this sample itself is the first meaningful movement.
        if !isInPet, let lastMotionAt, time - lastMotionAt > trackingPauseSeconds {
            resetTracking(at: inputAngle)
        }

        let motionStep = max(0.025, excursionDegrees * 0.15)
        if let motionReference {
            if abs(inputAngle - motionReference) >= motionStep {
                self.motionReference = inputAngle
                lastMotionAt = time
            }
        } else {
            motionReference = inputAngle
            lastMotionAt = time
        }

        if isInPet {
            if let lastMotionAt, time - lastMotionAt >= petRestSeconds {
                isInPet = false
                lastTriggerAt = nil
                resetTracking(at: inputAngle)
                return false
            }
        }

        if time < suppressedUntil { return false }
        guard let anchor else {
            self.anchor = inputAngle
            return false
        }

        let displacement = inputAngle - anchor
        let maximumDisplacement = max(1.5, excursionDegrees * 2.75)
        if abs(inputAngle - (origin ?? anchor)) > maximumDisplacement ||
            ((peak != nil || completedWiggles > 0) &&
             time - startedAt > maximumGestureSeconds) {
            rejectMovement(at: inputAngle, time: time)
            return false
        }

        guard let peak else {
            if abs(displacement) >= excursionDegrees * 0.95 {
                direction = displacement > 0 ? 1 : -1
                self.peak = inputAngle
                peakAt = time
                if completedWiggles == 0 {
                    startedAt = time
                    origin = anchor
                }
            }
            return false
        }

        if direction * (inputAngle - peak) > 0 {
            self.peak = inputAngle
            peakAt = time
            return false
        }

        let returnDistance = direction * (peak - inputAngle)
        // The live center allows pressure on the screen to shift the resting
        // angle without demanding a return to the old stroke's exact start.
        let deltaFromBaseline = inputAngle - (baselineDegrees ?? anchor)
        let centerDistance = min(abs(displacement), abs(deltaFromBaseline))
        guard returnDistance >= excursionDegrees * 0.6,
              centerDistance <= excursionDegrees * 0.9,
              time - peakAt >= minimumReversalSeconds else { return false }

        completedWiggles += 1
        let wiggleExcursion = abs(peak - anchor)
        self.peak = nil
        direction = 0
        let requiredWiggles = isInPet ? 1 : 2
        guard completedWiggles == requiredWiggles else {
            firstWiggleExcursion = wiggleExcursion
            self.anchor = inputAngle
            return false
        }
        if !isInPet && wiggleExcursion < firstWiggleExcursion * 0.35 {
            rejectMovement(at: inputAngle, time: time)
            return false
        }
        guard time - startedAt >= 0.18 else {
            rejectMovement(at: inputAngle, time: time)
            return false
        }

        let shouldTrigger = !isInPet ||
            (lastTriggerAt.map { time - $0 >= repeatIntervalSeconds } ?? false)
        resetTracking(at: inputAngle)
        guard shouldTrigger else { return false }
        isInPet = true
        lastTriggerAt = time
        lastMotionAt = time
        motionReference = inputAngle
        return true
    }

    private mutating func resetTracking(at angle: Double?) {
        anchor = angle
        origin = nil
        peak = nil
        peakAt = 0
        direction = 0
        completedWiggles = 0
        startedAt = 0
        firstWiggleExcursion = 0
    }

    private mutating func rejectMovement(at angle: Double, time: TimeInterval) {
        resetTracking(at: angle)
        motionReference = angle
        lastMotionAt = time
        suppressedUntil = time + 0.2
    }
}
