import XCTest
import AppKit

#if canImport(vmux_DEV)
@testable import vmux_DEV
#elseif canImport(vmux)
@testable import vmux
#endif

@MainActor
final class GhosttyEnsureFocusWindowActivationTests: XCTestCase {
    func testAllowsActivationForActiveManager() {
        let activeManager = TabManager()
        let otherManager = TabManager()

        XCTAssertTrue(
            shouldAllowEnsureFocusWindowActivation(
                activeTabManager: activeManager,
                targetTabManager: activeManager,
                keyWindow: NSWindow(),
                mainWindow: NSWindow()
            )
        )
        XCTAssertFalse(
            shouldAllowEnsureFocusWindowActivation(
                activeTabManager: activeManager,
                targetTabManager: otherManager,
                keyWindow: NSWindow(),
                mainWindow: NSWindow()
            )
        )
    }

    func testAllowsActivationWhenAppHasNoKeyAndNoMainWindow() {
        let targetManager = TabManager()

        XCTAssertTrue(
            shouldAllowEnsureFocusWindowActivation(
                activeTabManager: nil,
                targetTabManager: targetManager,
                keyWindow: nil,
                mainWindow: nil
            )
        )
        XCTAssertFalse(
            shouldAllowEnsureFocusWindowActivation(
                activeTabManager: nil,
                targetTabManager: targetManager,
                keyWindow: NSWindow(),
                mainWindow: nil
            )
        )
        XCTAssertFalse(
            shouldAllowEnsureFocusWindowActivation(
                activeTabManager: nil,
                targetTabManager: targetManager,
                keyWindow: nil,
                mainWindow: NSWindow()
            )
        )
    }
}
