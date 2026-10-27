import Foundation

/// Recognizes the small, rapid oscillations seen in precise hinge reports.
/// Six alternating lobes are required before a message can be sent.
struct RapidPetDetector {
    var distanceDegrees = 0.03
    private(set) var baselineDegrees: Double?
    private(set) var completedWiggles = 0
    private(set) var isInPet = false
    private(set) var observedCycleSeconds: Double?
    private(set) var observedSwingDegrees: Double?

    private struct Edge {
        let time: Double
        let amplitude: Double
        let baseline: Double
    }

    private var filteredDegrees: Double?
    private var lastSampleAt: Double?
    private var phase = 0
    private var candidatePhase = 0
    private var candidateAt = 0.0
    private var extreme = 0.0
    private var edges: [Edge] = []
    private var lastEdgeAt: Double?
    private var lastTriggerAt: Double?
    private var edgesSinceTrigger = 100

    mutating func reset(at angle: Double? = nil) {
        baselineDegrees = angle
        filteredDegrees = angle
        lastSampleAt = nil
        phase = 0
        candidatePhase = 0
        candidateAt = 0
        extreme = 0
        edges.removeAll(keepingCapacity: true)
        lastEdgeAt = nil
        lastTriggerAt = nil
        edgesSinceTrigger = 100
        completedWiggles = 0
        isInPet = false
        observedCycleSeconds = nil
        observedSwingDegrees = nil
    }

    mutating func consume(angle: Double, at time: Double) -> Bool {
        guard angle.isFinite, (45...165).contains(angle), time.isFinite else {
            reset()
            return false
        }
        if let lastSampleAt, time - lastSampleAt > 1.5 {
            reset(at: angle)
        }
        let interval = lastSampleAt.map { time - $0 } ?? 0
        lastSampleAt = time
        if let filteredDegrees, let baselineDegrees, interval > 0 {
            self.filteredDegrees = filteredDegrees +
                (1 - exp(-interval / 0.025)) * (angle - filteredDegrees)
            self.baselineDegrees = baselineDegrees +
                (1 - exp(-interval / 0.45)) * (angle - baselineDegrees)
        } else {
            filteredDegrees = angle
            baselineDegrees = angle
        }
        let delta = (filteredDegrees ?? angle) - (baselineDegrees ?? angle)

        if let lastEdgeAt, time - lastEdgeAt > 2 {
            isInPet = false
            phase = 0
            candidatePhase = 0
            edges.removeAll(keepingCapacity: true)
            self.lastEdgeAt = nil
            completedWiggles = 0
        }

        let threshold = max(0.012, distanceDegrees * 0.65)
        let newPhase = delta >= threshold ? 1 : (delta <= -threshold ? -1 : 0)
        guard newPhase != 0, newPhase != phase else {
            candidatePhase = 0
            if phase != 0, delta * Double(phase) > 0, abs(delta) > abs(extreme) {
                extreme = delta
            }
            return false
        }
        if candidatePhase != newPhase {
            candidatePhase = newPhase
            candidateAt = time
            return false
        }
        guard time - candidateAt >= 0.03 else { return false }
        candidatePhase = 0

        if phase == 0 {
            phase = newPhase
            extreme = delta
            return false
        }
        if let lastEdgeAt {
            let gap = time - lastEdgeAt
            if gap < 0.07 || gap > 0.75 {
                edges.removeAll(keepingCapacity: true)
            }
        }
        edges.append(Edge(time: time, amplitude: abs(extreme),
                          baseline: baselineDegrees ?? angle))
        if edges.count > 8 { edges.removeFirst() }
        edgesSinceTrigger += 1
        phase = newPhase
        extreme = delta
        lastEdgeAt = time
        completedWiggles = min(2, edges.count / 2)

        guard edges.count >= 6 else { return false }
        let recent = Array(edges.suffix(6))
        let intervals = (1..<6).map { recent[$0].time - recent[$0 - 1].time }
        let medianInterval = Self.median(intervals)
        let mean = intervals.reduce(0, +) / Double(intervals.count)
        let variance = intervals.map { pow($0 - mean, 2) }.reduce(0, +) /
            Double(intervals.count)
        let variation = sqrt(variance) / mean
        let earlyAmplitude = Self.median(recent.prefix(2).map(\.amplitude))
        let lateAmplitude = Self.median(recent.suffix(2).map(\.amplitude))
        let baselineShift = abs(recent[5].baseline - recent[0].baseline)
        guard recent[5].time - recent[0].time <= 2.3,
              (0.08...0.3).contains(medianInterval),
              variation <= 0.85,
              lateAmplitude >= earlyAmplitude * 0.42,
              baselineShift <= max(0.16, distanceDegrees * 4) else { return false }

        observedCycleSeconds = medianInterval * 2
        observedSwingDegrees = Self.median(recent.map(\.amplitude)) * 2
        guard edgesSinceTrigger >= 4,
              lastTriggerAt.map({ time - $0 >= 2.5 }) ?? true else { return false }
        lastTriggerAt = time
        edgesSinceTrigger = 0
        isInPet = true
        completedWiggles = 0
        return true
    }

    private static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        let center = sorted.count / 2
        return sorted.count.isMultiple(of: 2)
            ? (sorted[center - 1] + sorted[center]) / 2 : sorted[center]
    }
}
