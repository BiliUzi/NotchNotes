import AppKit
import XCTest
@testable import NotchNotes

@MainActor
final class NotchGeometryTests: XCTestCase {
    func testCenterTopActivationFrameUsesSixthOfScreenWidthAndMenuBarHeight() {
        XCTAssertEqual(
            NotchGeometry.centerTopActivationFrame(
                screenFrame: NSRect(x: 0, y: 0, width: 1920, height: 1080),
                menuBarHeight: 32
            ),
            NSRect(x: 800, y: 1048, width: 320, height: 32)
        )
    }

    func testCenterTopActivationFrameAccountsForScreenOrigin() {
        XCTAssertEqual(
            NotchGeometry.centerTopActivationFrame(
                screenFrame: NSRect(x: 100, y: 50, width: 1500, height: 900),
                menuBarHeight: 30
            ),
            NSRect(x: 725, y: 920, width: 250, height: 30)
        )
    }

    func testCenterTopActivationFrameIsNilWithoutMenuBarHeight() {
        XCTAssertEqual(
            NotchGeometry.centerTopActivationFrame(
                screenFrame: NSRect(x: 0, y: 0, width: 1920, height: 1080),
                menuBarHeight: 0
            ),
            nil
        )
    }
}
