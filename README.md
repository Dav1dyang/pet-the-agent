# Pet the Agent

A tiny macOS menu-bar app that turns gentle MacBook screen petting into a playful call-and-response for a focused prompt in **Warp, Codex, Claude, or Cursor**. Continued petting sends one short line at a time, then sweet compliments with a few gentle coding jokes.

## Get started

1. Download and unzip [Pet the Agent.zip](dist/Pet%20the%20Agent.zip), then open **Pet the Agent.app**. If you are updating, quit the old menu-bar app first.
2. Click the paw in the menu bar. Check that **Screen angle** shows a live number.
3. Set **Pet distance**. A smaller number needs a smaller screen wiggle.
4. Click **Test a pet** and gently rock the screen back and forth **twice**, then keep petting. The twelve-second test previews each line and shows the **Adaptive center** following the screen angle. You can stop it at any time. The test never types into another app.
5. Allow **Accessibility** when prompted and switch on **Send compliments**. Close the menu, then focus an empty chat prompt in Warp, Codex, Claude, or Cursor before petting.

The app uses only the hinge-angle sensor. Two back-and-forth strokes near the starting angle begin petting. Gentle strokes can take up to ten seconds, and the first line is sent as soon as the second stroke returns—no need to stop moving. Keep petting and another completed stroke can send the next line, with at least **2.5 seconds** between sends. The opening is **“Who is a good boy?” → “Who is a good boy?” → “You are a good boy!” → “Yes you are!”** Each line is a separate message. After that, continued petting sends a random sweet compliment. Holding the screen still does not send more; about 1.5 seconds of rest resets the opening for the next petting session. A one-way move, single settling bounce, wide adjustment, or two unrelated strokes separated by a pause does not count. When precise readings are available, the distance can be set as low as **0.1°**. Some Macs provide only whole-degree readings; their minimum is **1°**. If 0.1° is too sensitive to sensor noise, increase the distance and test again.

The detector uses two time-based exponential averages, adapted from a fast-input/slow-baseline sensor filter: the input responds in 25–50 ms, while the adaptive center responds in 0.45 seconds. A stroke counts when the filtered input clearly reverses toward either its local starting angle or the moving center. The return must exceed 60% of the selected Pet distance and take at least 0.12 seconds; the first two strokes must also be reasonably similar in size. These checks reduce jitter and settling bounces while the center follows screen pressure and drift without manual calibration.

Petting starts off every time the app opens. A compliment is sent only while one of the four supported apps is frontmost; the menu itself must be closed. The app types the message and presses Return. It skips sending if you pressed a key in the last 1.5 seconds, to avoid interrupting active typing. A skipped pet shows a short notice, then returns to its normal status. Keep petting for another stroke or rest the screen and try again. The app does not read another app's content or automatically find its chat input, so **focus an empty prompt first**. A paused, unfinished draft could still receive text. In Cursor, a focused code editor could receive the text instead of chat.

The messages are praise and jokes; none asks an agent to edit files, run commands, or change tasks. They still arrive as chat messages, so an agent may reply.

If the menu reports that hinge access was denied, allow **Input Monitoring** for the app in System Settings → Privacy & Security and reopen it. Accessibility permission is needed to type into supported apps. This download is ad hoc signed and is not notarized, so macOS may ask you to approve its first launch.

## Build and test

Requires macOS 14 or later, Xcode Command Line Tools, and Swift 6. Run `./build-app.sh` to create an app bundle in `dist/`; run `swift test` for the gesture and report-decoding checks.

The lid-angle feature report layout follows the observations in [Clamshell's sensor code](https://github.com/danielradosa/clamshell/blob/main/Sources/Clamshell/Sensor/LidAngleSensor.swift). This sensor interface is undocumented by Apple and may differ by Mac or macOS version.
