import AppKit
import XCTest
@testable import NotchNotes

@MainActor
final class NotchGeometryTests: XCTestCase {
    func testCenterTopHoverFrameUsesScreenWidthFractionAndVisibleBounds() {
        XCTAssertEqual(
            NotchGeometry.centerTopHoverFrame(
                screenFrame: NSRect(x: 0, y: 0, width: 1920, height: 1080),
                visibleFrame: NSRect(x: 0, y: 0, width: 1920, height: 1049),
                menuBarHeight: 30
            ),
            NSRect(x: 800, y: 1050, width: 320, height: 30)
        )
    }

    func testCenterTopHoverFrameIsNilWithoutMenuBar() {
        XCTAssertEqual(
            NotchGeometry.centerTopHoverFrame(
                screenFrame: NSRect(x: 0, y: 0, width: 1920, height: 1080),
                visibleFrame: NSRect(x: 0, y: 0, width: 1920, height: 1080),
                menuBarHeight: 30
            ),
            nil
        )
    }

    func testCenterTopHoverFrameNeverExtendsBelowReservedTopArea() {
        XCTAssertEqual(
            NotchGeometry.centerTopHoverFrame(
                screenFrame: NSRect(x: 100, y: 50, width: 1500, height: 900),
                visibleFrame: NSRect(x: 100, y: 50, width: 1500, height: 880),
                menuBarHeight: 30
            ),
            NSRect(x: 725, y: 930, width: 250, height: 20)
        )
    }
}
