# Pet the Agent

A tiny macOS menu-bar app that turns a gentle MacBook screen wiggle into a random, sweet pet-style compliment for a focused prompt in **Warp, Codex, Claude, or Cursor**. Some messages ask “Who is a good boy?” twice, and a few mix in gentle coding jokes.

## Get started

1. Download and unzip [Pet the Agent.zip](dist/Pet%20the%20Agent.zip), then open **Pet the Agent.app**. If you are updating, quit the old menu-bar app first.
2. Click the paw in the menu bar. Check that **Screen angle** shows a live number.
3. Set **Pet distance**. A smaller number needs a smaller screen wiggle.
4. Click **Test a pet** and gently rock the screen back and forth **twice**. The twelve-second test ends as soon as it feels the second stroke, and you can stop it at any time. The menu shows when it counts the first stroke. The test never types into another app.
5. Allow **Accessibility** when prompted and switch on **Send compliments**. Close the menu, then focus an empty chat prompt in Warp, Codex, Claude, or Cursor before petting.

The app uses only the hinge-angle sensor. A pet is two back-and-forth strokes near the starting angle. Gentle strokes can take up to ten seconds, and the pet is detected as soon as the second stroke returns—no need to stop moving. Continuing to pet the screen counts as the **same pet**, with one compliment. Let the screen rest for about 1.5 seconds before starting another. A one-way move, single settling bounce, wide adjustment, or two unrelated strokes separated by a pause does not count. When precise readings are available, the distance can be set as low as **0.1°**. Some Macs provide only whole-degree readings; their minimum is **1°**. If 0.1° is too sensitive to sensor noise, increase the distance and test again.

Petting starts off every time the app opens. A compliment is sent only while one of the four supported apps is frontmost; the menu itself must be closed. The app types the message and presses Return. It skips sending if you pressed a key in the last 1.5 seconds, to avoid interrupting active typing. A skipped pet shows a short notice, then returns to its normal status. Rest the screen before trying another pet. The app does not read another app's content or automatically find its chat input, so **focus an empty prompt first**. A paused, unfinished draft could still receive text. In Cursor, a focused code editor could receive the text instead of chat.

The messages are praise and jokes; none asks an agent to edit files, run commands, or change tasks. They still arrive as chat messages, so an agent may reply.

If the menu reports that hinge access was denied, allow **Input Monitoring** for the app in System Settings → Privacy & Security and reopen it. Accessibility permission is needed to type into supported apps. This download is ad hoc signed and is not notarized, so macOS may ask you to approve its first launch.

## Build and test

Requires macOS 14 or later, Xcode Command Line Tools, and Swift 6. Run `./build-app.sh` to create an app bundle in `dist/`; run `swift test` for the gesture and report-decoding checks.

The lid-angle feature report layout follows the observations in [Clamshell's sensor code](https://github.com/danielradosa/clamshell/blob/main/Sources/Clamshell/Sensor/LidAngleSensor.swift). This sensor interface is undocumented by Apple and may differ by Mac or macOS version.
