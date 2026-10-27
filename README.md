# Pet the Agent

A tiny macOS menu-bar app. Gently move a compatible MacBook screen away and back to send a random compliment to the active Claude or Codex prompt in Warp. One variant says, “Who is a good boy?” twice.

## Use

1. Unzip `dist/Pet the Agent.zip` and open **Pet the Agent.app**. You can also build it from source with `./build-app.sh`.
2. Click the paw in the menu bar and allow Accessibility when prompted.
3. Open a Claude or Codex session in Warp, put the cursor in its prompt, then switch **Petting is on**.
4. Move the screen out by roughly 2° and back. The app types one compliment and presses Return. Adjust **Movement needed** if desired.

The app starts disarmed every launch. It sends only while Warp is frontmost, waits 15 seconds between messages, and never reads your terminal contents. It cannot tell whether Warp is showing a Claude/Codex prompt or a shell prompt, so check the active prompt before arming. It does not launch Warp or any agent.

If the menu says sensor access was denied, enable **Input Monitoring** for the app in System Settings → Privacy & Security, then reopen it. Accessibility is also needed to type into Warp.

The MacBook lid-angle HID interface is undocumented and may differ by model or macOS version. Unsupported Macs show a sensor error in the menu. This app was built against macOS 27 on an Apple Silicon MacBook Pro with the `las` sensor.

## Build and test

Requires macOS 14 or later, Xcode Command Line Tools, and Swift 6. Run `swift test` for the gesture checks. The build script creates an ad hoc signed app bundle in `dist/`.

The sensor report layout and HID identifiers were checked against [Sam Gold's LidAngleSensor project](https://github.com/samhenrigold/LidAngleSensor/blob/main/LidAngleSensor/LidAngleSensor.swift).
