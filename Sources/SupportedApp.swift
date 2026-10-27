import Foundation

enum SupportedApp: String, CaseIterable, Identifiable {
    case warp
    case codex
    case claude
    case cursor

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .warp: "Warp"
        case .codex: "Codex"
        case .claude: "Claude"
        case .cursor: "Cursor"
        }
    }

    private var bundleIdentifier: String {
        switch self {
        case .warp: "dev.warp.Warp-Stable"
        case .codex: "com.openai.codex"
        case .claude: "com.anthropic.claudefordesktop"
        case .cursor: "com.todesktop.230313mzl4w4u92"
        }
    }

    static func matching(bundleIdentifier: String?) -> SupportedApp? {
        guard let bundleIdentifier else { return nil }
        return allCases.first { $0.bundleIdentifier == bundleIdentifier }
    }
}
