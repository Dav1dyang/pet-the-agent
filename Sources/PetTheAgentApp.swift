import SwiftUI
import Combine

@main
struct PetTheAgentApp: App {
    @NSApplicationDelegateAdaptor(PetAppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

@MainActor
private final class PetAppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private let controller = PetController()
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let popover = NSPopover()
    private var iconObservation: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let host = NSHostingController(rootView: PetMenu(controller: controller))
        host.sizingOptions = [.preferredContentSize]

        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = host
        popover.delegate = self
        popover.contentSize = host.sizeThatFits(
            in: CGSize(width: 358, height: 1000)
        )

        if let button = statusItem.button {
            button.toolTip = "Pet the Agent"
            button.target = self
            button.action = #selector(togglePopover(_:))
        }

        iconObservation = controller.$armed.combineLatest(controller.$justReceivedPet)
            .sink { [weak self] armed, justReceivedPet in
                MainActor.assumeIsolated {
                    self?.updateStatusIcon(armed: armed, justReceivedPet: justReceivedPet)
                }
        }
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            button.state = .on
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func popoverDidClose(_ notification: Notification) {
        statusItem.button?.state = .off
    }

    private func updateStatusIcon(armed: Bool, justReceivedPet: Bool) {
        let symbol = justReceivedPet ? "heart.fill" : (armed ? "pawprint.fill" : "pawprint")
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Pet the Agent")
        image?.isTemplate = true
        statusItem.button?.image = image
    }
}

private struct PetMenu: View {
    @ObservedObject var controller: PetController

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            statusCard
            hingeControls

            if let outcome = controller.testOutcome {
                testResult(outcome)
            }

            Divider()
            sendingControls

            if let lastSent = controller.lastSent {
                VStack(alignment: .leading, spacing: 4) {
                    Text("LAST TO \(controller.lastSentApp?.displayName.uppercased() ?? "APP") · \(controller.sentCount) SENT")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.8)
                        .foregroundStyle(.secondary)
                    Text(lastSent)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            }

            HStack {
                Text("Keep petting for the next line · at least 2.5s apart")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                Button("Quit") { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .frame(width: 358)
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
                Text("A little encouragement, one pet at a time")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
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
                Text(String(format: "%.1f°", controller.sensitivity))
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .monospacedDigit()
            }
            Slider(value: sensitivityBinding,
                   in: controller.hingeMinimumDegrees...5)
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
                      ? "Stop test · \(controller.testSecondsRemaining)s"
                      : "Test a pet",
                      systemImage: controller.testing ? "stop.fill" : "hand.tap")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(!controller.hingeAvailable)

            Text("Two gentle strokes start a pet. Keep moving to hear the next line. Testing previews the words but never sends.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
    }

    private var sendingControls: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Send compliments")
                        .font(.subheadline.weight(.semibold))
                    Text("Warp · Codex · Claude · Cursor")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("Send compliments", isOn: $controller.armed)
                    .labelsHidden()
                    .tint(.teal)
                    .disabled(!controller.hingeAvailable ||
                              !controller.accessibilityAllowed ||
                              controller.testing)
            }

            if !controller.accessibilityAllowed && controller.hingeAvailable {
                Button("Allow Accessibility…") {
                    controller.requestAccessibility()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }

            Text("Close this menu and focus an empty chat prompt before petting. A pet just after typing won't send. In Cursor, a focused code editor can receive text.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
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
                 : "No pet detected. Try two gentle strokes or adjust the distance.")
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(10)
        .background((detected ? Color.green : Color.orange).opacity(0.09),
                    in: RoundedRectangle(cornerRadius: 10))
    }

    private var angleLabel: String {
        guard let angle = controller.angle else { return "—" }
        return String(format: controller.hingeResolutionDegrees < 1 ? "%.2f°" : "%.0f°", angle)
    }

    private var sensitivityBinding: Binding<Double> {
        Binding(
            get: { controller.sensitivity },
            set: { value in
                let step = controller.hingeResolutionDegrees < 1 ? 0.1 : 1.0
                let rounded = (value / step).rounded() * step
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
            if controller.testWiggles == 1 {
                return ("One stroke felt", "Keep petting gently for one more stroke.",
                        "waveform", .teal)
            }
            return ("Listening for a pet", "Move gently back and forth twice.",
                    "waveform", .teal)
        }
        if controller.armed {
            if controller.skippedWhileTyping {
                return ("Pet felt", "A key was just pressed, so nothing was sent. Keep petting or rest and try again.",
                        "hand.raised.fill", .orange)
            }
            if !controller.targetAppReady {
                return ("Back to your chat", "Close this menu and focus an empty chat prompt to send.",
                        "arrow.uturn.forward", .teal)
            }
            return ("Petting is on", "Focus a chat prompt in Warp, Codex, Claude, or Cursor.",
                    "pawprint.fill", .teal)
        }
        if !controller.accessibilityAllowed {
            return ("Ready to test", "Allow Accessibility before sending compliments.",
                    "hand.tap.fill", .accentColor)
        }
        return ("Ready for a pet", "Test two gentle strokes, then turn on compliments.",
                "checkmark.circle.fill", .green)
    }
}
