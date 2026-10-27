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

            HStack {
                Label("Screen angle", systemImage: "laptopcomputer")
                Spacer()
                Text(controller.angle.map { "\(Int($0))°" } ?? "—")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Text(controller.status)
                .font(.subheadline)
                .foregroundStyle(controller.sensorError == nil ? Color.secondary : Color.red)
                .fixedSize(horizontal: false, vertical: true)

            if !controller.accessibilityAllowed {
                Button("Allow Accessibility…") { controller.requestAccessibility() }
                    .buttonStyle(.borderedProminent)
            }

            Toggle("Petting is on", isOn: $controller.armed)
                .disabled(controller.sensorError != nil || !controller.accessibilityAllowed)

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text("Movement needed")
                    Spacer()
                    Text("\(Int(controller.sensitivity))°")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Slider(value: $controller.sensitivity, in: 1...5, step: 1)
                Text("Move the screen slightly away and back. One message per pet, with a 15-second pause.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            Text("Messages go to the focused Warp window and are submitted with Return. Keep a Claude or Codex prompt active there.")
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
        .frame(width: 330)
    }
}
