import AppKit
@preconcurrency import ApplicationServices

@MainActor
enum WarpMessenger {
    static let bundleID = "dev.warp.Warp-Stable"

    static var isWarpFrontmost: Bool {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier == bundleID
    }

    static var hasAccessibilityAccess: Bool { AXIsProcessTrusted() }

    static func requestAccessibilityAccess() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    /// Sends a single line to the currently focused Warp input, then presses Return.
    static func send(_ message: String) -> Bool {
        guard hasAccessibilityAccess, isWarpFrontmost,
              !message.contains("\n"), !message.contains("\r"),
              let source = CGEventSource(stateID: .hidSystemState) else { return false }

        let characters = Array(message.utf16)
        guard !characters.isEmpty, characters.count < 200,
              let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false),
              let enterDown = CGEvent(keyboardEventSource: source, virtualKey: 36, keyDown: true),
              let enterUp = CGEvent(keyboardEventSource: source, virtualKey: 36, keyDown: false)
        else { return false }

        characters.withUnsafeBufferPointer { buffer in
            guard let base = buffer.baseAddress else { return }
            down.keyboardSetUnicodeString(stringLength: buffer.count, unicodeString: base)
            up.keyboardSetUnicodeString(stringLength: buffer.count, unicodeString: base)
        }
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        enterDown.post(tap: .cghidEventTap)
        enterUp.post(tap: .cghidEventTap)
        return true
    }
}
