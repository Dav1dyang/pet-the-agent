import AppKit
import Combine

enum TriggerSensor: String, CaseIterable, Identifiable {
    case hinge
    case accelerometer

    var id: String { rawValue }
    var title: String {
        switch self {
        case .hinge: "Hinge angle"
        case .accelerometer: "Motion sensor"
        }
    }
}

@MainActor
final class PetController: ObservableObject {
    @Published private(set) var angle: Double?
    @Published private(set) var hingeError: String?
    @Published private(set) var hingeResolutionDegrees = 1.0
    @Published private(set) var motionActivityG: Double?
    @Published private(set) var motionPeakG = 0.0
    @Published private(set) var motionError: String?
    @Published private(set) var motionDeviceFound = false
    @Published private(set) var motionLive = false
    @Published private(set) var accessibilityAllowed = WarpMessenger.hasAccessibilityAccess
    @Published private(set) var warpFrontmost = false
    @Published private(set) var lastSent: String?
    @Published private(set) var sentCount = 0
    @Published private(set) var testing = false
    @Published private(set) var testResult: String?

    @Published var triggerSensor: TriggerSensor = .hinge {
        didSet {
            UserDefaults.standard.set(triggerSensor.rawValue, forKey: "triggerSensor")
            armed = false
            testing = false
            testResult = nil
            hingeDetector.reset(at: angle)
            motionDetector.reset()
        }
    }

    @Published var armed = false {
        didSet {
            hingeDetector.reset(at: angle)
            motionDetector.reset()
        }
    }

    @Published var sensitivity: Double = 0.1 {
        didSet {
            UserDefaults.standard.set(sensitivity, forKey: "hingeSensitivityDegreesV2")
            hingeDetector.excursionDegrees = sensitivity
            hingeDetector.reset(at: angle)
        }
    }

    @Published var motionThresholdG: Double = 0.03 {
        didSet {
            UserDefaults.standard.set(motionThresholdG, forKey: "motionThresholdG")
            motionDetector.thresholdG = motionThresholdG
            motionDetector.reset()
        }
    }

    private var hingeDetector = PetGestureDetector(excursionDegrees: 0.1)
    private var motionDetector = MotionPulseDetector()
    private var lastPermissionCheck = 0.0
    private var lastMotionDisplayUpdate = 0.0
    private var testTimer: Timer?

    private lazy var hingeSensor = HingeSensor(
        onAngle: { [weak self] value in self?.receive(angle: value) },
        onError: { [weak self] message in
            self?.hingeError = message
            if self?.triggerSensor == .hinge { self?.armed = false }
        }
    )

    private lazy var accelerometer = AccelerometerSensor(
        onActivity: { [weak self] activity, time in
            self?.receive(motionActivity: activity, at: time)
        },
        onError: { [weak self] message in
            self?.motionError = message.isEmpty ? nil : message
            if !message.isEmpty, self?.triggerSensor == .accelerometer { self?.armed = false }
        }
    )

    init() {
        let savedHinge = UserDefaults.standard.double(forKey: "hingeSensitivityDegreesV2")
        if (0.1...5).contains(savedHinge) { sensitivity = savedHinge }
        let savedMotion = UserDefaults.standard.double(forKey: "motionThresholdG")
        if (0.005...0.1).contains(savedMotion) { motionThresholdG = savedMotion }
        hingeDetector.excursionDegrees = sensitivity
        motionDetector.thresholdG = motionThresholdG

        hingeError = hingeSensor.error
        hingeResolutionDegrees = hingeSensor.resolutionDegrees
        if hingeResolutionDegrees >= 1, sensitivity < 1 { sensitivity = 1 }
        hingeSensor.start()

        motionError = accelerometer.error
        motionDeviceFound = accelerometer.deviceFound
        if let saved = UserDefaults.standard.string(forKey: "triggerSensor"),
           let mode = TriggerSensor(rawValue: saved) {
            triggerSensor = mode
        }
    }

    var hingeMinimumDegrees: Double { hingeResolutionDegrees < 1 ? 0.1 : 1 }

    var selectedSensorAvailable: Bool {
        switch triggerSensor {
        case .hinge: hingeError == nil && angle != nil
        case .accelerometer: motionLive && motionError == nil
        }
    }

    var status: String {
        switch triggerSensor {
        case .hinge:
            if let hingeError { return hingeError }
            if angle == nil { return "Waiting for a hinge reading…" }
        case .accelerometer:
            if let motionError { return motionError }
            if !motionLive { return "Waiting for accelerometer readings…" }
        }
        if testing { return "Testing this sensor. Move the MacBook now." }
        if !accessibilityAllowed { return "Allow Accessibility to send messages." }
        if !armed { return "Ready. Turn on petting when you want to use it." }
        if !warpFrontmost { return "Armed. Switch to your Warp agent prompt." }
        return "Armed. A pet will send one compliment."
    }

    func requestAccessibility() {
        WarpMessenger.requestAccessibilityAccess()
        accessibilityAllowed = WarpMessenger.hasAccessibilityAccess
    }

    func startTest() {
        armed = false
        testing = true
        testResult = "Move the screen gently during the next 8 seconds."
        motionPeakG = 0
        hingeDetector.reset(at: angle)
        motionDetector.reset()
        testTimer?.invalidate()
        let newTimer = Timer(timeInterval: 8, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.testing else { return }
                self.finishTest(success: false)
            }
        }
        RunLoop.main.add(newTimer, forMode: .common)
        testTimer = newTimer
    }

    private func finishTest(success: Bool) {
        testTimer?.invalidate()
        testTimer = nil
        testing = false
        hingeDetector = PetGestureDetector(excursionDegrees: sensitivity)
        motionDetector = MotionPulseDetector(thresholdG: motionThresholdG)
        if success {
            testResult = "Pet detected! This setting works without sending a message."
        } else if triggerSensor == .accelerometer, !motionLive {
            testResult = "No accelerometer readings arrived. Try hinge angle instead."
        } else {
            testResult = "No pet detected. Try a lower threshold or a slightly larger movement."
        }
    }

    private func refreshPermissions(at time: TimeInterval) {
        if time - lastPermissionCheck > 1 {
            accessibilityAllowed = WarpMessenger.hasAccessibilityAccess
            warpFrontmost = WarpMessenger.isWarpFrontmost
            lastPermissionCheck = time
        }
    }

    private func receive(angle newAngle: Double) {
        angle = newAngle
        let now = ProcessInfo.processInfo.systemUptime
        refreshPermissions(at: now)
        guard triggerSensor == .hinge else {
            hingeDetector.reset(at: newAngle)
            return
        }
        if testing {
            if hingeDetector.consume(angle: newAngle, at: now) { finishTest(success: true) }
            return
        }
        guard armed, accessibilityAllowed, warpFrontmost else {
            hingeDetector.reset(at: newAngle)
            return
        }
        if hingeDetector.consume(angle: newAngle, at: now) { sendCompliment() }
    }

    private func receive(motionActivity activity: Double, at time: TimeInterval) {
        motionLive = true
        motionError = nil
        if time - lastMotionDisplayUpdate > 0.08 {
            motionActivityG = activity
            lastMotionDisplayUpdate = time
        }
        if testing, triggerSensor == .accelerometer { motionPeakG = max(motionPeakG, activity) }
        refreshPermissions(at: time)
        guard triggerSensor == .accelerometer else {
            motionDetector.reset()
            return
        }
        if testing {
            if motionDetector.consume(activityG: activity, at: time) { finishTest(success: true) }
            return
        }
        guard armed, accessibilityAllowed, warpFrontmost else {
            motionDetector.reset()
            return
        }
        if motionDetector.consume(activityG: activity, at: time) { sendCompliment() }
    }

    private func sendCompliment() {
        let message = Compliments.random(excluding: lastSent)
        if WarpMessenger.send(message) {
            lastSent = message
            sentCount += 1
        }
    }
}
