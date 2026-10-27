# Pet the Agent

A tiny macOS menu-bar app that turns a gentle MacBook screen wiggle into a random compliment for the active Claude or Codex prompt in Warp. One message asks “Who is a good boy?” twice.

## Get started

1. Download and unzip [Pet the Agent.zip](dist/Pet%20the%20Agent.zip), then open **Pet the Agent.app**.
2. Click the paw in the menu bar. Check that **Screen angle** shows a live number.
3. Set **Pet distance**. A smaller number needs a smaller out-and-back screen movement.
4. Click **Test a pet** and move the screen during the eight-second test. The test never types into Warp.
5. Allow **Accessibility** when prompted. Open a Claude or Codex prompt in Warp, then switch on **Send compliments**.

The app uses only the hinge-angle sensor. When precise readings are available, the distance can be set as low as **0.1°**. Some Macs provide only whole-degree readings; their minimum is **1°**. If 0.1° is too sensitive to sensor noise, increase the distance and test again.

Petting starts off every time the app opens. A compliment is sent only while Warp is frontmost, with at least 15 seconds between sends. The app types the message and presses Return; it does not read terminal contents or check whether the active Warp prompt is for Claude or Codex.

If the menu reports that hinge access was denied, allow **Input Monitoring** for the app in System Settings → Privacy & Security and reopen it. Accessibility permission is needed to type into Warp. This download is ad hoc signed and is not notarized, so macOS may ask you to approve its first launch.

## Build and test

Requires macOS 14 or later, Xcode Command Line Tools, and Swift 6. Run `./build-app.sh` to create an app bundle in `dist/`; run `swift test` for the gesture and report-decoding checks.

The lid-angle feature report layout follows the observations in [Clamshell's sensor code](https://github.com/danielradosa/clamshell/blob/main/Sources/Clamshell/Sensor/LidAngleSensor.swift). This sensor interface is undocumented by Apple and may differ by Mac or macOS version.
