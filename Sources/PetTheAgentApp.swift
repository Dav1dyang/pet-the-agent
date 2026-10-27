import SwiftUI

@main
struct PetTheAgentApp: App {
    @StateObject private var controller = PetController()

    var body: some Scene {
        MenuBarExtra {
            PetMenu(controller: controller)
        } label: {
            Label("Pet the Agent", systemImage: controller.armed ? "pawprint.fill" : "pawprint")
        }
        .menuBarExtraStyle(.window)
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
                Text("One compliment per pet · 3 seconds between pets")
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
                Text("A little encouragement, one wiggle away")
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

            Divider()

            HStack(alignment: .firstTextBaseline) {
                Text("Pet distance")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text(String(format: "%.1f°", controller.sensitivity))
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .monospacedDigit()
            }
            Slider(value: $controller.sensitivity,
                   in: controller.hingeMinimumDegrees...5,
                   step: controller.hingeResolutionDegrees < 1 ? 0.1 : 1)
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
                controller.startTest()
            } label: {
                Label(controller.testing
                      ? "Listening… \(controller.testSecondsRemaining)s"
                      : "Test a pet",
                      systemImage: controller.testing ? "waveform" : "hand.tap")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(!controller.hingeAvailable || controller.testing)

            Text("Tip the screen out and back. Testing never sends a message.")
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

            Text("Focus a chat prompt before petting. In Cursor, the code editor can also receive typing.")
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
                 ? "Pet detected! That wiggle works. Nothing was sent."
                 : "No pet detected. Try a bigger wiggle or lower the distance.")
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

    private var status: (title: String, detail: String, symbol: String, tint: Color) {
        if let error = controller.hingeError {
            return ("Hinge unavailable", error, "exclamationmark.triangle.fill", .orange)
        }
        if !controller.hingeAvailable {
            return ("Finding your hinge", "Waiting for the first screen-angle reading…",
                    "laptopcomputer", .secondary)
        }
        if controller.testing {
            return ("Listening for a pet", "Gently move the screen out and back.",
                    "waveform", .teal)
        }
        if controller.armed {
            return ("Petting is on", "Focus a chat prompt in Warp, Codex, Claude, or Cursor.",
                    "pawprint.fill", .teal)
        }
        if !controller.accessibilityAllowed {
            return ("Ready to test", "Allow Accessibility before sending compliments.",
                    "hand.tap.fill", .accentColor)
        }
        return ("Ready for a pet", "Test your wiggle, then turn on compliments.",
                "checkmark.circle.fill", .green)
    }
}
