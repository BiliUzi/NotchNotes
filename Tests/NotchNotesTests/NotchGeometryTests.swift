import AppKit
import XCTest
@testable import NotchNotes

@MainActor
final class NotchGeometryTests: XCTestCase {
    func testCenterTopActivationFrameUsesFixedSize() {
        XCTAssertEqual(
            NotchGeometry.centerTopActivationFrame(
                screenFrame: NSRect(x: 0, y: 0, width: 1920, height: 1080)
            ),
            NSRect(x: 810, y: 1050, width: 300, height: 30)
        )
    }

    func testCenterTopActivationFrameAccountsForScreenOrigin() {
        XCTAssertEqual(
            NotchGeometry.centerTopActivationFrame(
                screenFrame: NSRect(x: 100, y: 50, width: 1500, height: 900)
            ),
            NSRect(x: 700, y: 920, width: 300, height: 30)
        )
    }

    func testCenterTopActivationFrameIsNilForScreenSmallerThanTarget() {
        XCTAssertEqual(
            NotchGeometry.centerTopActivationFrame(
                screenFrame: NSRect(x: 0, y: 0, width: 299, height: 200)
            ),
            nil
        )
    }
}
