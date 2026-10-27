import AppKit
import Combine
import UniformTypeIdentifiers

enum PetTestOutcome: Equatable {
    case detected
    case missed
}

@MainActor
final class PetController: ObservableObject {
    @Published private(set) var angle: Double?
    @Published private(set) var hingeError: String?
    @Published private(set) var hingeResolutionDegrees = 1.0
    @Published private(set) var calibratedCenter: Double?
    @Published private(set) var accessibilityAllowed = AppMessenger.hasAccessibilityAccess
    @Published private(set) var lastSent: String?
    @Published private(set) var lastSentApp: SupportedApp?
    @Published private(set) var sentCount = 0
    @Published private(set) var testing = false
    @Published private(set) var testSecondsRemaining = 0
    @Published private(set) var testWiggles = 0
    @Published private(set) var testPetCount = 0
    @Published private(set) var testPhrase: String?
    @Published private(set) var testOutcome: PetTestOutcome?
    @Published private(set) var calibration: HingeCalibration?
    @Published private(set) var hasRecording = false
    @Published private(set) var recordingError: String?
    @Published private(set) var skippedWhileTyping = false
    @Published private(set) var targetAppReady = false
    @Published private(set) var justReceivedPet = false

    @Published var armed = false {
        didSet {
            hingeDetector.reset(at: angle)
            liveSequence.reset()
            skippedWhileTyping = false
        }
    }

    @Published var sensitivity: Double = 0.03 {
        didSet {
            UserDefaults.standard.set(sensitivity, forKey: "hingeSensitivityDegreesV3")
            hingeDetector.excursionDegrees = sensitivity
            hingeDetector.reset(at: angle)
            liveSequence.reset()
            testOutcome = nil
        }
    }

    private var hingeDetector = PetGestureDetector(excursionDegrees: 0.03)
    private var liveSequence = PettingSequence()
    private var testSequence = PettingSequence()
    private var lastPermissionCheck = 0.0
    private var testTimer: Timer?
    private var petFeedbackTimer: Timer?
    private var skipNoticeUntil = 0.0
    private var testStartedAt = 0.0
    private var testSamples: [HingeSample] = []

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
        let saved = UserDefaults.standard.double(forKey: "hingeSensitivityDegreesV3")
        let previous = UserDefaults.standard.double(forKey: "hingeSensitivityDegreesV2")
        if (0.02...5).contains(saved) {
            sensitivity = saved
        } else if previous > 0.1, previous <= 5 {
            sensitivity = previous
        }
        hingeDetector.excursionDegrees = sensitivity

        hingeError = hingeSensor.error
        hingeResolutionDegrees = hingeSensor.resolutionDegrees
        if hingeResolutionDegrees >= 1, sensitivity < 1 { sensitivity = 1 }
        hingeSensor.start()
    }

    var hingeMinimumDegrees: Double { hingeResolutionDegrees < 1 ? 0.02 : 1 }
    var hingeAvailable: Bool { hingeError == nil && angle != nil }

    func requestAccessibility() {
        AppMessenger.requestAccessibilityAccess()
        accessibilityAllowed = AppMessenger.hasAccessibilityAccess
    }

    func startTest() {
        guard hingeAvailable, !testing else { return }
        testing = true
        testSecondsRemaining = 15
        testWiggles = 0
        testPetCount = 0
        testPhrase = nil
        testOutcome = nil
        calibration = nil
        hasRecording = false
        recordingError = nil
        testSamples.removeAll(keepingCapacity: true)
        testStartedAt = ProcessInfo.processInfo.systemUptime
        hingeDetector = PetGestureDetector(excursionDegrees: sensitivity)
        calibratedCenter = angle
        liveSequence.reset()
        testSequence.reset()

        testTimer?.invalidate()
        let newTimer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.testing else { return }
                self.testSecondsRemaining -= 1
                if self.testSecondsRemaining == 0 {
                    self.finishTest(outcome: self.testPetCount > 0 ? .detected : .missed)
                }
            }
        }
        RunLoop.main.add(newTimer, forMode: .common)
        testTimer = newTimer
    }

    func cancelTest() {
        guard testing else { return }
        finishTest(outcome: testPetCount > 0 ? .detected : nil)
    }

    private func finishTest(outcome: PetTestOutcome?) {
        testTimer?.invalidate()
        testTimer = nil
        testing = false
        testSecondsRemaining = 0
        testWiggles = 0
        testOutcome = outcome
        hasRecording = !testSamples.isEmpty
        calibration = HingeRecording.calibration(
            from: testSamples, minimumDistance: hingeMinimumDegrees
        )
        hingeDetector = PetGestureDetector(excursionDegrees: sensitivity)
        liveSequence.reset()
    }

    func useSuggestedDistance() {
        guard let calibration else { return }
        sensitivity = calibration.suggestedDistance
    }

    func saveRecording() {
        guard hasRecording else { return }
        let panel = NSSavePanel()
        panel.title = "Save hinge recording"
        panel.nameFieldStringValue = "Pet the Agent hinge recording.csv"
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try HingeRecording.csv(testSamples).write(
                to: url, atomically: true, encoding: .utf8
            )
            recordingError = nil
        } catch {
            recordingError = "Couldn't save the recording. Please try another location."
        }
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
        if skippedWhileTyping && now >= skipNoticeUntil {
            skippedWhileTyping = false
        }
        let supportedApp = AppMessenger.frontmostSupportedApp
        if targetAppReady != (supportedApp != nil) {
            targetAppReady = supportedApp != nil
        }

        if testing {
            let wasPetting = hingeDetector.isInPet
            let detected = hingeDetector.consume(angle: newAngle, at: now)
            testSamples.append(HingeSample(
                seconds: now - testStartedAt,
                angle: newAngle,
                baseline: hingeDetector.baselineDegrees ?? newAngle,
                petEvent: detected
            ))
            calibratedCenter = hingeDetector.baselineDegrees
            if wasPetting && !hingeDetector.isInPet { testSequence.reset() }
            if testWiggles != hingeDetector.completedWiggles {
                testWiggles = hingeDetector.completedWiggles
            }
            if detected {
                testPetCount += 1
                testPhrase = testSequence.next(excluding: testPhrase)
                showPetFeedback()
            }
            return
        }

        guard armed, accessibilityAllowed, supportedApp != nil else {
            hingeDetector.reset(at: newAngle)
            liveSequence.reset()
            return
        }
        let wasPetting = hingeDetector.isInPet
        let detected = hingeDetector.consume(angle: newAngle, at: now)
        if wasPetting && !hingeDetector.isInPet { liveSequence.reset() }
        if detected {
            sendCompliment()
        }
    }

    private func sendCompliment() {
        if AppMessenger.isUserTyping {
            skippedWhileTyping = true
            skipNoticeUntil = ProcessInfo.processInfo.systemUptime + 2.5
            return
        }
        var nextSequence = liveSequence
        let message = nextSequence.next(excluding: lastSent)
        if let app = AppMessenger.send(message) {
            liveSequence = nextSequence
            skippedWhileTyping = false
            lastSent = message
            lastSentApp = app
            sentCount += 1
            showPetFeedback()
        }
    }

    private func showPetFeedback() {
        justReceivedPet = true
        petFeedbackTimer?.invalidate()
        let timer = Timer(timeInterval: 1.2, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.justReceivedPet = false }
        }
        RunLoop.main.add(timer, forMode: .common)
        petFeedbackTimer = timer
    }
}
