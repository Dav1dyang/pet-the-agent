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
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "pawprint.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.mint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Pet the Agent")
                        .font(.headline)
                    Text("A little encouragement for Claude or Codex")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            Picker("Trigger sensor", selection: $controller.triggerSensor) {
                ForEach(TriggerSensor.allCases) { sensor in
                    Text(sensor.title).tag(sensor)
                }
            }
            .pickerStyle(.segmented)

            if controller.triggerSensor == .hinge {
                hingeControls
            } else {
                motionControls
            }

            Text(controller.status)
                .font(.subheadline)
                .foregroundStyle(currentError == nil ? Color.secondary : Color.red)
                .fixedSize(horizontal: false, vertical: true)

            Button(controller.testing ? "Testing…" : "Test this sensor") {
                controller.startTest()
            }
            .buttonStyle(.bordered)
            .disabled(controller.testing || (controller.triggerSensor == .hinge && controller.hingeError != nil))

            if let result = controller.testResult {
                Text(result)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !controller.accessibilityAllowed {
                Button("Allow Accessibility…") { controller.requestAccessibility() }
                    .buttonStyle(.borderedProminent)
            }

            Toggle("Petting is on", isOn: $controller.armed)
                .disabled(!controller.selectedSensorAvailable || !controller.accessibilityAllowed || controller.testing)

            Divider()

            Text("One compliment per pet, with a 15-second pause. Messages go to the focused Warp window and are submitted with Return. Keep a Claude or Codex prompt active there.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let lastSent = controller.lastSent {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Last compliment · \(controller.sentCount) sent")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(lastSent)
                        .font(.caption)
                }
            }

            HStack {
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .frame(width: 350)
    }

    private var hingeControls: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Label("Screen angle", systemImage: "laptopcomputer")
                Spacer()
                Text(controller.angle.map { String(format: "%.2f°", $0) } ?? "—")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            if controller.hingeError == nil {
                Text(controller.hingeResolutionDegrees < 1
                     ? "Precise hinge readings available (0.01° steps)."
                     : "This Mac is using whole-degree hinge readings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Movement needed")
                Spacer()
                Text(String(format: "%.1f°", controller.sensitivity))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: $controller.sensitivity,
                   in: controller.hingeMinimumDegrees...5,
                   step: controller.hingeResolutionDegrees < 1 ? 0.1 : 1)
            Text("Gently move the screen out and back. Try 0.1° in Test mode first; tiny readings can include sensor noise.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var motionControls: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Label("Accelerometer", systemImage: "waveform.path")
                Spacer()
                Text(controller.motionLive ? "Live" : (controller.motionDeviceFound ? "Found" : "Not found"))
                    .foregroundStyle(controller.motionLive ? Color.green : Color.secondary)
            }
            HStack {
                Text("Current movement")
                Spacer()
                Text(controller.motionActivityG.map { String(format: "%.3f g", $0) } ?? "—")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            if controller.testing {
                HStack {
                    Text("Peak during test")
                    Spacer()
                    Text(String(format: "%.3f g", controller.motionPeakG))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            HStack {
                Text("Movement needed")
                Spacer()
                Text(String(format: "%.3f g", controller.motionThresholdG))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: $controller.motionThresholdG, in: 0.005...0.1, step: 0.005)
            Text("This sensor feels movement of the MacBook body, so a tiny screen-only movement may not register.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var currentError: String? {
        controller.triggerSensor == .hinge ? controller.hingeError : controller.motionError
    }
}
