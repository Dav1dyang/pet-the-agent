import XCTest
@testable import PetTheAgent

final class SupportedAppTests: XCTestCase {
    func testRecognizesTheFourSupportedApps() {
        XCTAssertEqual(SupportedApp.matching(bundleIdentifier: "dev.warp.Warp-Stable"), .warp)
        XCTAssertEqual(SupportedApp.matching(bundleIdentifier: "com.openai.codex"), .codex)
        XCTAssertEqual(SupportedApp.matching(bundleIdentifier: "com.anthropic.claudefordesktop"), .claude)
        XCTAssertEqual(SupportedApp.matching(bundleIdentifier: "com.todesktop.230313mzl4w4u92"), .cursor)
    }

    func testRejectsOtherApps() {
        XCTAssertNil(SupportedApp.matching(bundleIdentifier: nil))
        XCTAssertNil(SupportedApp.matching(bundleIdentifier: "com.apple.Terminal"))
        XCTAssertNil(SupportedApp.matching(bundleIdentifier: "com.openai.chat"))
    }
}
