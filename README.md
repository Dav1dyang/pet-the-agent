# Pet the Agent

A tiny macOS menu-bar app. Gently pet a MacBook screen to send a random compliment to the active Claude or Codex prompt in Warp. One variant says, “Who is a good boy?” twice.

## Use

1. Download and unzip [Pet the Agent.zip](dist/Pet%20the%20Agent.zip), then open **Pet the Agent.app**. You can also build it from source with `./build-app.sh`.
2. Click the paw in the menu bar. Pick **Hinge angle** or **Motion sensor**.
3. Click **Test this sensor** and move the screen during the eight-second test. The test never types into Warp. Watch the live angle or motion reading and adjust **Movement needed** until the test detects your gesture.
4. Allow Accessibility when prompted. Open a Claude or Codex session in Warp, put the cursor in its prompt, then switch **Petting is on**.

**Hinge angle** uses a fine-resolution report when available. It can detect an out-and-back movement as small as 0.1°; the menu shows the angle to two decimals. Some Macs only provide whole-degree readings, in which case the minimum setting is 1°. At 0.1°, sensor noise can occasionally look like movement, so use the test to tune it.

**Motion sensor** reads the MacBook accelerometer and detects a short movement burst followed by rest. It senses movement of the laptop body, so a tiny screen-only movement may not register. The menu shows whether live readings arrive and the peak signal during the test. macOS may restrict this undocumented sensor; if no readings arrive, the app disables arming in this mode and the hinge mode remains available. The app does not ask for administrator access.

The app starts disarmed every launch. It sends only while Warp is frontmost, waits 15 seconds between messages, and never reads terminal contents. It cannot tell whether Warp is showing a Claude/Codex prompt or a shell prompt, so check the active prompt before arming. It does not launch Warp or any agent.

If the menu says hinge sensor access was denied, enable **Input Monitoring** for the app in System Settings → Privacy & Security, then reopen it. Accessibility is needed to type into Warp.

## Build and test

Requires macOS 14 or later, Xcode Command Line Tools, and Swift 6. Run `swift test` for the gesture checks. The build script creates an ad hoc signed app bundle in `dist/`.

The lid angle feature report layout follows the documented observations in [Clamshell's sensor code](https://github.com/danielradosa/clamshell/blob/main/Sources/Clamshell/Sensor/LidAngleSensor.swift). The accelerometer report layout follows the observations in [macimu](https://github.com/junwatu/macimu/blob/main/Sources/MacIMU/IMU.swift). Both sensor interfaces are undocumented by Apple and may differ by Mac or macOS version.
