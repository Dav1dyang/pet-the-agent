import AppKit
import Combine

enum PetTestOutcome: Equatable {
    case detected
    case missed
}

@MainActor
final class PetController: ObservableObject {
    @Published private(set) var angle: Double?
    @Published private(set) var hingeError: String?
    @Published private(set) var hingeResolutionDegrees = 1.0
    @Published private(set) var accessibilityAllowed = AppMessenger.hasAccessibilityAccess
    @Published private(set) var lastSent: String?
    @Published private(set) var lastSentApp: SupportedApp?
    @Published private(set) var sentCount = 0
    @Published private(set) var testing = false
    @Published private(set) var testSecondsRemaining = 0
    @Published private(set) var testOutcome: PetTestOutcome?

    @Published var armed = false {
        didSet { hingeDetector.reset(at: angle) }
    }

    @Published var sensitivity: Double = 0.1 {
        didSet {
            UserDefaults.standard.set(sensitivity, forKey: "hingeSensitivityDegreesV2")
            hingeDetector.excursionDegrees = sensitivity
            hingeDetector.reset(at: angle)
            testOutcome = nil
        }
    }

    private var hingeDetector = PetGestureDetector(excursionDegrees: 0.1)
    private var lastPermissionCheck = 0.0
    private var testTimer: Timer?

    private lazy var hingeSensor = HingeSensor(
        onAngle: { [weak self] value in self?.receive(angle: value) },
        onError: { [weak self] message in
            guard let self else { return }
            self.hingeError = message
            self.armed = false
            if self.testing { self.finishTest(outcome: nil) }
        }
    )

    init() {
        let saved = UserDefaults.standard.double(forKey: "hingeSensitivityDegreesV2")
        if (0.1...5).contains(saved) { sensitivity = saved }
        hingeDetector.excursionDegrees = sensitivity

        hingeError = hingeSensor.error
        hingeResolutionDegrees = hingeSensor.resolutionDegrees
        if hingeResolutionDegrees >= 1, sensitivity < 1 { sensitivity = 1 }
        hingeSensor.start()
    }

    var hingeMinimumDegrees: Double { hingeResolutionDegrees < 1 ? 0.1 : 1 }
    var hingeAvailable: Bool { hingeError == nil && angle != nil }

    func requestAccessibility() {
        AppMessenger.requestAccessibilityAccess()
        accessibilityAllowed = AppMessenger.hasAccessibilityAccess
    }

    func startTest() {
        guard hingeAvailable, !testing else { return }
        testing = true
        testSecondsRemaining = 8
        testOutcome = nil
        hingeDetector = PetGestureDetector(excursionDegrees: sensitivity)

        testTimer?.invalidate()
        let newTimer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.testing else { return }
                self.testSecondsRemaining -= 1
                if self.testSecondsRemaining == 0 {
                    self.finishTest(outcome: .missed)
                }
            }
        }
        RunLoop.main.add(newTimer, forMode: .common)
        testTimer = newTimer
    }

    private func finishTest(outcome: PetTestOutcome?) {
        testTimer?.invalidate()
        testTimer = nil
        testing = false
        testSecondsRemaining = 0
        testOutcome = outcome
        hingeDetector = PetGestureDetector(excursionDegrees: sensitivity)
    }

    private func refreshPermissions(at time: TimeInterval) {
        if time - lastPermissionCheck > 1 {
            accessibilityAllowed = AppMessenger.hasAccessibilityAccess
            if !accessibilityAllowed { armed = false }
            lastPermissionCheck = time
        }
    }

    private func receive(angle newAngle: Double) {
        angle = newAngle
        let now = ProcessInfo.processInfo.systemUptime
        refreshPermissions(at: now)

        if testing {
            if hingeDetector.consume(angle: newAngle, at: now) {
                finishTest(outcome: .detected)
            }
            return
        }

        guard armed, accessibilityAllowed, AppMessenger.frontmostSupportedApp != nil else {
            hingeDetector.reset(at: newAngle)
            return
        }
        if hingeDetector.consume(angle: newAngle, at: now) {
            sendCompliment()
        }
    }

    private func sendCompliment() {
        let message = Compliments.random(excluding: lastSent)
        if let app = AppMessenger.send(message) {
            lastSent = message
            lastSentApp = app
            sentCount += 1
        }
    }
}
