import AppKit
@preconcurrency import ApplicationServices

@MainActor
enum AppMessenger {
    static var frontmostSupportedApp: SupportedApp? {
        SupportedApp.matching(
            bundleIdentifier: NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        )
    }

    static var hasAccessibilityAccess: Bool { AXIsProcessTrusted() }

    static func requestAccessibilityAccess() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    /// Types one line into the focused input of a supported app, then presses Return.
    static func send(_ message: String) -> SupportedApp? {
        guard hasAccessibilityAccess, let app = frontmostSupportedApp,
              !message.contains("\n"), !message.contains("\r"),
              let source = CGEventSource(stateID: .hidSystemState) else { return nil }

        let characters = Array(message.utf16)
        guard !characters.isEmpty, characters.count < 200,
              let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false),
              let enterDown = CGEvent(keyboardEventSource: source, virtualKey: 36, keyDown: true),
              let enterUp = CGEvent(keyboardEventSource: source, virtualKey: 36, keyDown: false)
        else { return nil }

        characters.withUnsafeBufferPointer { buffer in
            guard let base = buffer.baseAddress else { return }
            down.keyboardSetUnicodeString(stringLength: buffer.count, unicodeString: base)
            up.keyboardSetUnicodeString(stringLength: buffer.count, unicodeString: base)
        }

        guard frontmostSupportedApp == app else { return nil }
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        enterDown.post(tap: .cghidEventTap)
        enterUp.post(tap: .cghidEventTap)
        return app
    }
}
