# Pet the Agent

A tiny macOS menu-bar app that turns gentle MacBook screen petting into a playful call-and-response for a focused prompt in **Warp, Codex, Claude, or Cursor**. Continued petting sends one short line at a time, then sweet compliments with a few gentle coding jokes.

## Get started

1. Download and unzip [Pet the Agent.zip](dist/Pet%20the%20Agent.zip), then open **Pet the Agent.app**. If you are updating, quit the old menu-bar app first.
2. **Left-click the paw** in the menu bar to turn petting on or off. An outline paw means off; a filled paw means on. If macOS asks for Accessibility, allow it and click the paw again.
3. **Right-click the paw** for a small settings menu. It shows the live screen angle, a **Pet distance** submenu, **Test & tune…**, Accessibility access when needed, and Quit.
4. Choose **Test & tune…** to open a compact window with the live hinge angle and distance slider. Click **Record & tune a pet** and gently pet the screen back and forth at a steady pace. The 15-second test previews detections and shows the moving center. You can stop it at any time. The test never types into another app.
5. If a steady rhythm was found, click **Use suggested distance**. **Save hinge data…** exports the recorded angles, moving center, and detected events as a CSV file for closer inspection. The fine-sensor default is **0.03°**; recordings from the first two real MacBook tests suggested **0.02°** and **0.03°**. Focus an empty chat prompt in Warp, Codex, Claude, or Cursor before petting.

The app uses only the hinge-angle sensor. On Macs with precise readings, **0.02–0.09°** uses a rapid-petting detector: six alternating small movements establish a rhythm before the first line. Further messages require fresh movement and at least **2.5 seconds** between sends. The moving center follows screen pressure and drift, while a one-way adjustment or settling bounce does not count. Larger distances use the original three-stroke detector for slower, broader petting. The opening is **“Who is a good boy?” → “Who is a good boy?” → “You are a good boy!” → “Yes you are!”** Each line is a separate message. After that, continued petting sends a random sweet compliment. Holding the screen still does not send more. Some Macs provide only whole-degree readings; their minimum is **1°**.

The rapid detector uses a 25 ms input filter and a 0.45 second moving center. It requires sustained, alternating movement with a fairly regular pace and rejects a rapidly fading bounce. When the screen moves far from its center, the detector immediately follows the new angle, clears partial rhythm evidence, and listens for petting again without sending for the adjustment itself. Ongoing petting needs four new direction changes for another line; a new petting session needs six. The larger-stroke detector retains its 25–50 ms input filter, 0.45 second center, and three-stroke check. The recording tool replays the trace at several candidate distances, suggests the setting that recognizes the most sustained petting, and applies nothing until you click **Use suggested distance**. Broad screen adjustments cannot be used as a fallback distance suggestion. The recording stays in memory until you close the app or start a new recording; it is only written to disk when you choose **Save hinge data…**. Personal hinge recordings are not included in this repository.

Petting starts off every time the app opens. A compliment is sent only while one of the four supported apps is frontmost. The app types the message and presses Return. It skips sending if you pressed a key in the last 1.5 seconds, to avoid interrupting active typing. A skipped pet shows a short notice, then returns to its normal status. Keep petting for another stroke or rest the screen and try again. The app does not read another app's content or automatically find its chat input, so **focus an empty prompt first**. A paused, unfinished draft could still receive text. In Cursor, a focused code editor could receive the text instead of chat.

The messages are praise and jokes; none asks an agent to edit files, run commands, or change tasks. They still arrive as chat messages, so an agent may reply.

If the menu reports that hinge access was denied, allow **Input Monitoring** for the app in System Settings → Privacy & Security and reopen it. Accessibility permission is needed to type into supported apps. This download is ad hoc signed and is not notarized, so macOS may ask you to approve its first launch.

## Build and test

Requires macOS 14 or later, Xcode Command Line Tools, and Swift 6. Run `./build-app.sh` to create an app bundle in `dist/`; run `swift test` for the gesture and report-decoding checks.

The lid-angle feature report layout follows the observations in [Clamshell's sensor code](https://github.com/danielradosa/clamshell/blob/main/Sources/Clamshell/Sensor/LidAngleSensor.swift). This sensor interface is undocumented by Apple and may differ by Mac or macOS version.
