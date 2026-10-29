import AppKit
import SwiftUI
import Combine

@MainActor
@main
struct PetTheAgentApp {
    private static let appDelegate = PetAppDelegate()

    static func main() {
        let app = NSApplication.shared
        app.delegate = appDelegate
        app.run()
    }
}

@MainActor
private final class PetAppDelegate: NSObject, NSApplicationDelegate {
    private let controller = PetController()
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private var settingsWindow: NSWindow?
    private var iconObservation: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        iconObservation = controller.$armed.combineLatest(controller.$justReceivedPet)
            .sink { [weak self] armed, justReceivedPet in
                MainActor.assumeIsolated {
                    self?.updateStatusIcon(armed: armed, justReceivedPet: justReceivedPet)
                }
        }
    }

    @objc private func statusItemClicked(_ sender: Any?) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showSettingsMenu()
        } else {
            togglePetting()
        }
    }

    private func togglePetting() {
        if controller.armed {
            controller.armed = false
            return
        }
        guard !controller.testing else { return }
        guard controller.hingeAvailable else {
            NSSound.beep()
            return
        }
        if !controller.accessibilityAllowed {
            controller.requestAccessibility()
            guard controller.accessibilityAllowed else { return }
        }
        controller.armed = true
    }

    private func showSettingsMenu() {
        guard let button = statusItem.button, let event = NSApp.currentEvent else { return }
        let menu = NSMenu(title: "Pet the Agent")
        menu.autoenablesItems = false

        let status = NSMenuItem(title: statusTitle, action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)

        let toggle = NSMenuItem(title: controller.armed ? "Turn petting off" : "Turn petting on",
                                action: #selector(toggleFromMenu(_:)), keyEquivalent: "")
        toggle.target = self
        toggle.isEnabled = controller.armed || (controller.hingeAvailable && !controller.testing)
        menu.addItem(toggle)
        menu.addItem(.separator())

        let distance = NSMenuItem(title: "Pet distance · \(distanceLabel)", action: nil,
                                  keyEquivalent: "")
        distance.submenu = makeDistanceMenu()
        menu.addItem(distance)

        let tune = NSMenuItem(title: "Test & tune…", action: #selector(openSettings(_:)),
                              keyEquivalent: "")
        tune.target = self
        menu.addItem(tune)

        if !controller.accessibilityAllowed && controller.hingeAvailable {
            let permission = NSMenuItem(title: "Allow Accessibility…",
                                        action: #selector(requestAccessibility(_:)),
                                        keyEquivalent: "")
            permission.target = self
            menu.addItem(permission)
        }

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Pet the Agent", action: #selector(quitApp(_:)),
                              keyEquivalent: "")
        quit.target = self
        menu.addItem(quit)
        NSMenu.popUpContextMenu(menu, with: event, for: button)
    }

    private func makeDistanceMenu() -> NSMenu {
        let menu = NSMenu(title: "Pet distance")
        let choices: [Double] = controller.hingeMinimumDegrees >= 1
            ? [1, 2, 3, 4, 5]
            : [0.02, 0.03, 0.04, 0.05, 0.08, 0.1, 0.2, 0.5, 1, 2, 5]
        for value in choices {
            if (value == 0.1 || value == 1) && !menu.items.isEmpty {
                menu.addItem(.separator())
            }
            let label = value < 0.1 ? String(format: "%.2f°", value)
                        : (value < 1 ? String(format: "%.1f°", value)
                           : String(format: "%.0f°", value))
            let item = NSMenuItem(title: label, action: #selector(selectDistance(_:)),
                                  keyEquivalent: "")
            item.target = self
            item.representedObject = NSNumber(value: value)
            item.state = abs(controller.sensitivity - value) < 0.001 ? .on : .off
            menu.addItem(item)
        }
        return menu
    }

    @objc private func toggleFromMenu(_ sender: Any?) { togglePetting() }

    @objc private func selectDistance(_ sender: NSMenuItem) {
        guard let number = sender.representedObject as? NSNumber else { return }
        controller.sensitivity = number.doubleValue
    }

    @objc private func requestAccessibility(_ sender: Any?) {
        controller.requestAccessibility()
    }

    @objc private func openSettings(_ sender: Any?) {
        if settingsWindow == nil {
            let host = NSHostingController(rootView: PetMenu(controller: controller))
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 358, height: 430),
                                  styleMask: [.titled, .closable], backing: .buffered,
                                  defer: false)
            window.title = "Pet the Agent · Test & tune"
            window.contentViewController = host
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quitApp(_ sender: Any?) { NSApp.terminate(nil) }

    private var statusTitle: String {
        if controller.hingeError != nil { return "Hinge unavailable" }
        if !controller.hingeAvailable { return "Finding the screen hinge…" }
        return "Petting \(controller.armed ? "on" : "off") · \(angleLabel)"
    }

    private var distanceLabel: String {
        String(format: controller.sensitivity < 0.1 ? "%.2f°" :
               (controller.sensitivity < 1 ? "%.1f°" : "%.0f°"), controller.sensitivity)
    }

    private var angleLabel: String {
        guard let angle = controller.angle else { return "—" }
        return String(format: controller.hingeResolutionDegrees < 1 ? "%.2f°" : "%.0f°", angle)
    }

    private func updateStatusIcon(armed: Bool, justReceivedPet: Bool) {
        let symbol = justReceivedPet ? "heart.fill" : (armed ? "pawprint.fill" : "pawprint")
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Pet the Agent")
        image?.isTemplate = true
        statusItem.button?.image = image
        statusItem.button?.toolTip = "Petting \(armed ? "on" : "off") · Click to \(armed ? "turn off" : "turn on") · Right-click for settings"
        statusItem.button?.setAccessibilityLabel("Pet the Agent, petting \(armed ? "on" : "off")")
    }
}

private struct PetMenu: View {
    @ObservedObject var controller: PetController
    @State private var tuningExpanded = true
    @State private var sendingExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    statusCard
                    DisclosureGroup(isExpanded: $tuningExpanded) {
                        VStack(alignment: .leading, spacing: 12) {
                            hingeControls
                            if let outcome = controller.testOutcome { testResult(outcome) }
                            if controller.hasRecording { recordingCard }
                        }
                        .padding(.top, 10)
                    } label: {
                        Label("Pet distance & recording", systemImage: "slider.horizontal.3")
                            .font(.subheadline.weight(.semibold))
                    }
                    Divider()
                    DisclosureGroup(isExpanded: $sendingExpanded) {
                        sendingControls.padding(.top, 10)
                    } label: {
                        Label("How sending works", systemImage: "text.bubble")
                            .font(.subheadline.weight(.semibold))
                    }
                    if let lastSent = controller.lastSent {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("LAST TO \(controller.lastSentApp?.displayName.uppercased() ?? "APP") · \(controller.sentCount) SENT")
                                .font(.system(size: 10, weight: .semibold))
                                .tracking(0.8)
                                .foregroundStyle(.secondary)
                            Text(lastSent)
                                .font(.caption)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Color.accentColor.opacity(0.08),
                                    in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(18)
            }
        }
        .frame(width: 358, height: 430)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "pawprint.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.teal)
                .frame(width: 38, height: 38)
                .background(Color.teal.opacity(0.14), in: RoundedRectangle(cornerRadius: 11))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Pet the Agent")
                    .font(.system(size: 17, weight: .semibold))
                Text("Click the menu bar paw to \(controller.armed ? "pause" : "start")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Circle()
                .fill(controller.armed ? Color.green : Color.secondary.opacity(0.4))
                .frame(width: 8, height: 8)
                .accessibilityLabel(controller.armed ? "Petting on" : "Petting off")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    private var statusCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: status.symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(status.tint)
                .frame(width: 30, height: 30)
                .background(status.tint.opacity(0.13), in: RoundedRectangle(cornerRadius: 8))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(status.title)
                    .font(.subheadline.weight(.semibold))
                Text(status.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
    }

    private var hingeControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Screen angle", systemImage: "laptopcomputer")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text(angleLabel)
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }

            Text(controller.hingeResolutionDegrees < 1
                 ? "Live hinge reading · 0.01° steps"
                 : "Whole-degree readings on this Mac · minimum 1°")
                .font(.caption2)
                .foregroundStyle(.secondary)

            if controller.testing, let center = controller.calibratedCenter {
                HStack {
                    Text("Adaptive center")
                    Spacer()
                    Text(String(format: controller.hingeResolutionDegrees < 1
                                ? "%.2f°" : "%.0f°", center))
                        .monospacedDigit()
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            Divider()

            HStack(alignment: .firstTextBaseline) {
                Text("Pet distance")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text(String(format: controller.sensitivity < 0.1 ? "%.2f°" : "%.1f°",
                            controller.sensitivity))
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .monospacedDigit()
            }
            Slider(value: sensitivityBinding, in: 0...1)
                .tint(.teal)
                .disabled(!controller.hingeAvailable || controller.testing)
                .accessibilityLabel("Pet distance")
            HStack {
                Text("Tiny wiggle")
                Spacer()
                Text("Bigger movement")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)

            Button {
                if controller.testing {
                    controller.cancelTest()
                } else {
                    controller.startTest()
                }
            } label: {
                Label(controller.testing
                      ? "Finish recording · \(controller.testSecondsRemaining)s"
                      : "Record & tune a pet",
                      systemImage: controller.testing ? "stop.fill" : "hand.tap")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(!controller.hingeAvailable)

            Text("Pet steadily back and forth for a few seconds. Tiny, quick pets work at 0.02–0.09°. Recording lasts 15 seconds and never sends.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var sendingControls: some View {
        VStack(alignment: .leading, spacing: 11) {
            if !controller.accessibilityAllowed && controller.hingeAvailable {
                Button("Allow Accessibility…") {
                    controller.requestAccessibility()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }

            Text("Focus an empty chat prompt in Warp, Codex, Claude, or Cursor before petting. A pet just after typing won't send. In Cursor, a focused code editor can receive text.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Keep petting for another line · at least 2.5 seconds apart")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func testResult(_ outcome: PetTestOutcome) -> some View {
        let detected = outcome == .detected
        return HStack(alignment: .top, spacing: 8) {
            Image(systemName: detected ? "checkmark.circle.fill" : "arrow.counterclockwise.circle.fill")
                .foregroundStyle(detected ? Color.green : Color.orange)
                .accessibilityHidden(true)
            Text(detected
                 ? "\(controller.testPetCount) \(controller.testPetCount == 1 ? "pet" : "pets") felt. Last line: “\(controller.testPhrase ?? "")” Nothing was sent."
                 : "No pet detected. Try a steady, quick back-and-forth rhythm or adjust the distance.")
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(10)
        .background((detected ? Color.green : Color.orange).opacity(0.09),
                    in: RoundedRectangle(cornerRadius: 10))
    }

    private var recordingCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            if let calibration = controller.calibration {
                Label("Your petting rhythm was captured", systemImage: "waveform.path")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.teal)
                Text(String(format: "About %.1f seconds per back-and-forth · %.2f° swing. Suggested pet distance: %.2f°.",
                            calibration.strokePeriod, calibration.swingDegrees,
                            calibration.suggestedDistance))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if abs(controller.sensitivity - calibration.suggestedDistance) > 0.001 {
                    Button("Use suggested distance") { controller.useSuggestedDistance() }
                        .buttonStyle(.borderedProminent)
                        .tint(.teal)
                }
            } else {
                Label("Recording saved", systemImage: "waveform.path")
                    .font(.subheadline.weight(.semibold))
                Text("A steady rhythm wasn't clear enough to suggest a distance. You can save the hinge data for a closer look.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Button("Save hinge data…") { controller.saveRecording() }
                .buttonStyle(.link)
                .font(.caption)
            if let error = controller.recordingError {
                Text(error).font(.caption).foregroundStyle(.red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.teal.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    private var angleLabel: String {
        guard let angle = controller.angle else { return "—" }
        return String(format: controller.hingeResolutionDegrees < 1 ? "%.2f°" : "%.0f°", angle)
    }

    private var sensitivityBinding: Binding<Double> {
        Binding(
            get: {
                let minimum = controller.hingeMinimumDegrees
                if minimum >= 1 {
                    return min(1, max(0, (controller.sensitivity - 1) / 4))
                }
                return min(1, max(0,
                                  log(controller.sensitivity / minimum) / log(5 / minimum)))
            },
            set: { value in
                let minimum = controller.hingeMinimumDegrees
                let distance = minimum >= 1
                    ? 1 + value * 4 : minimum * pow(5 / minimum, value)
                let step = minimum >= 1 ? 1.0 : (distance < 0.1 ? 0.01 : 0.1)
                let rounded = min(5, max(minimum, (distance / step).rounded() * step))
                if abs(controller.sensitivity - rounded) > 0.0001 {
                    controller.sensitivity = rounded
                }
            }
        )
    }

    private var status: (title: String, detail: String, symbol: String, tint: Color) {
        if let error = controller.hingeError {
            return ("Hinge unavailable", error, "exclamationmark.triangle.fill", .orange)
        }
        if !controller.hingeAvailable {
            return ("Finding your hinge", "Waiting for the first screen-angle reading…",
                    "laptopcomputer", .secondary)
        }
        if controller.testing {
            if controller.testPetCount > 0 {
                return ("\(controller.testPetCount) \(controller.testPetCount == 1 ? "pet" : "pets") felt",
                        "“\(controller.testPhrase ?? "")” Keep petting for the next line.",
                        "heart.fill", .teal)
            }
            if controller.testWiggles > 0 {
                return ("Finding your rhythm", "\(controller.testWiggles) of 3 steady strokes felt. Keep the same pace.",
                        "waveform", .teal)
            }
            return ("Recording petting", "Move gently back and forth at a steady pace.",
                    "waveform", .teal)
        }
        if controller.armed {
            if controller.skippedWhileTyping {
                return ("Pet felt", "A key was just pressed, so nothing was sent. Keep petting or rest and try again.",
                        "hand.raised.fill", .orange)
            }
            if !controller.targetAppReady {
                return ("Back to your chat", "Focus an empty chat prompt to send.",
                        "arrow.uturn.forward", .teal)
            }
            return ("Petting is on", "Focus a chat prompt in Warp, Codex, Claude, or Cursor.",
                    "pawprint.fill", .teal)
        }
        if !controller.accessibilityAllowed {
            return ("Ready to test", "Allow Accessibility before sending compliments.",
                    "hand.tap.fill", .accentColor)
        }
        return ("Ready for a pet", "Click the menu bar paw to turn on. Right-click to test and tune.",
                "checkmark.circle.fill", .green)
    }
}
