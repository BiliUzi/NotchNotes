import AppKit
import XCTest
@testable import NotchNotes

@MainActor
final class NotchGeometryTests: XCTestCase {
    func testClickActivationSizeFitsInsideMeasuredNotch() {
        let layout = NotchLayout(
            notchSize: NSSize(width: 210, height: 32),
            compactSize: NSSize(width: 204, height: 34),
            expandedSize: NSSize(width: 480, height: 408),
            compactTopOffset: 0,
            expandedTopOffset: 0
        )

        XCTAssertEqual(
            NotchGeometry.clickActivationSize(
                compactSize: layout.compactSize,
                notchLimitSize: layout.notchSize
            ),
            NSSize(width: 204, height: 32)
        )
    }

    func testClickActivationSizeClampsBothDimensionsToNotch() {
        let layout = NotchLayout(
            notchSize: NSSize(width: 180, height: 30),
            compactSize: NSSize(width: 200, height: 36),
            expandedSize: NSSize(width: 480, height: 408),
            compactTopOffset: 0,
            expandedTopOffset: 0
        )

        XCTAssertEqual(
            NotchGeometry.clickActivationSize(
                compactSize: layout.compactSize,
                notchLimitSize: layout.notchSize
            ),
            NSSize(width: 180, height: 30)
        )
    }

    func testCenterMenuBarFrameUsesScreenWidthFractionAndVisibleBounds() {
        XCTAssertEqual(
            NotchGeometry.centerMenuBarFrame(
                screenFrame: NSRect(x: 0, y: 0, width: 1920, height: 1080),
                visibleFrame: NSRect(x: 0, y: 0, width: 1920, height: 1049)
            ),
            NSRect(x: 800, y: 1049, width: 320, height: 31)
        )
    }

    func testPhysicalNotchFrameUsesAuxiliaryAreaGapAndBottomEdge() {
        XCTAssertEqual(
            NotchGeometry.physicalNotchFrame(
                screenFrame: NSRect(x: 0, y: 0, width: 1512, height: 982),
                leftArea: NSRect(x: 0, y: 958, width: 660, height: 24),
                rightArea: NSRect(x: 852, y: 958, width: 660, height: 24),
                notchHeight: 24
            ),
            NSRect(x: 660, y: 958, width: 192, height: 24)
        )
    }

    func testPhysicalNotchFrameIgnoresAuxiliaryAreaVerticalShape() {
        XCTAssertEqual(
            NotchGeometry.physicalNotchFrame(
                screenFrame: NSRect(x: 0, y: 0, width: 1512, height: 982),
                leftArea: NSRect(x: 0, y: 0, width: 660, height: 958),
                rightArea: NSRect(x: 852, y: 0, width: 660, height: 958),
                notchHeight: 24
            ),
            NSRect(x: 660, y: 958, width: 192, height: 24)
        )
    }

    func testCenterMenuBarFrameIsNilWithoutMenuBar() {
        XCTAssertEqual(
            NotchGeometry.centerMenuBarFrame(
                screenFrame: NSRect(x: 0, y: 0, width: 1920, height: 1080),
                visibleFrame: NSRect(x: 0, y: 0, width: 1920, height: 1080)
            ),
            nil
        )
    }
}
