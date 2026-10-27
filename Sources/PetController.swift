import AppKit
import Combine

@MainActor
final class PetController: ObservableObject {
    @Published private(set) var angle: Double?
    @Published private(set) var sensorError: String?
    @Published private(set) var accessibilityAllowed = WarpMessenger.hasAccessibilityAccess
    @Published private(set) var warpFrontmost = false
    @Published private(set) var lastSent: String?
    @Published private(set) var sentCount = 0

    @Published var armed = false {
        didSet { detector.reset(at: angle) }
    }

    @Published var sensitivity: Double = 2 {
        didSet {
            UserDefaults.standard.set(sensitivity, forKey: "petExcursionDegrees")
            detector.excursionDegrees = sensitivity
            detector.reset(at: angle)
        }
    }

    private var detector = PetGestureDetector()
    private var lastPermissionCheck = 0.0
    private lazy var sensor = HingeSensor(
        onAngle: { [weak self] value in self?.receive(angle: value) },
        onError: { [weak self] message in
            self?.sensorError = message
            self?.armed = false
        }
    )

    init() {
        let saved = UserDefaults.standard.double(forKey: "petExcursionDegrees")
        if (1...5).contains(saved) { sensitivity = saved }
        detector.excursionDegrees = sensitivity
        sensorError = sensor.error
        sensor.start()
    }

    var status: String {
        if let sensorError { return sensorError }
        if angle == nil { return "Waiting for a hinge reading…" }
        if !accessibilityAllowed { return "Allow Accessibility to send messages." }
        if !armed { return "Ready. Turn on petting when you want to use it." }
        if !warpFrontmost { return "Armed. Switch to your Warp agent prompt." }
        return "Armed. Gently move the screen out and back."
    }

    func requestAccessibility() {
        WarpMessenger.requestAccessibilityAccess()
        accessibilityAllowed = WarpMessenger.hasAccessibilityAccess
    }

    private func receive(angle newAngle: Double) {
        angle = newAngle
        let now = ProcessInfo.processInfo.systemUptime
        if now - lastPermissionCheck > 1 {
            accessibilityAllowed = WarpMessenger.hasAccessibilityAccess
            warpFrontmost = WarpMessenger.isWarpFrontmost
            lastPermissionCheck = now
        }

        guard armed, accessibilityAllowed, warpFrontmost else {
            detector.reset(at: newAngle)
            return
        }
        guard detector.consume(angle: newAngle, at: now) else { return }
        let message = Compliments.random(excluding: lastSent)
        if WarpMessenger.send(message) {
            lastSent = message
            sentCount += 1
        }
    }
}
