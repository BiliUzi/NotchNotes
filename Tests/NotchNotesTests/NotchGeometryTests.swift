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

    func testClickNotchLimitUsesConservativeWidthWithSafeArea() {
        XCTAssertEqual(
            NotchGeometry.clickNotchLimit(
                measuredNotchSize: .zero,
                safeAreaTop: 32
            ),
            NSSize(width: 120, height: 32)
        )
    }

    func testClickNotchLimitIsZeroWithoutNotchOrSafeArea() {
        XCTAssertEqual(
            NotchGeometry.clickNotchLimit(
                measuredNotchSize: .zero,
                safeAreaTop: 0
            ),
            .zero
        )
    }
}
