import AppKit
import CoreGraphics

struct NotchLayout: Equatable {
    let notchSize: NSSize
    let compactSize: NSSize
    let expandedSize: NSSize
    let compactTopOffset: CGFloat
    let expandedTopOffset: CGFloat
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        guard let number = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }

        return CGDirectDisplayID(number.uint32Value)
    }

    var isBuiltInDisplay: Bool {
        guard let displayID else { return false }
        return CGDisplayIsBuiltin(displayID) != 0
    }

    var measuredNotchSize: NSSize {
        guard #available(macOS 12.0, *), safeAreaInsets.top > 0 else {
            return .zero
        }

        guard let leftArea = auxiliaryTopLeftArea, let rightArea = auxiliaryTopRightArea else {
            return .zero
        }

        let notchWidth = frame.width - leftArea.width - rightArea.width
        guard notchWidth > 0, notchWidth < frame.width else {
            return .zero
        }

        return NSSize(width: notchWidth, height: safeAreaInsets.top)
    }

    var physicalNotchFrame: NSRect? {
        guard #available(macOS 12.0, *), safeAreaInsets.top > 0 else {
            return nil
        }

        guard let leftArea = auxiliaryTopLeftArea, let rightArea = auxiliaryTopRightArea else {
            return nil
        }

        return NotchGeometry.physicalNotchFrame(
            screenFrame: frame,
            leftArea: leftArea,
            rightArea: rightArea,
            notchHeight: safeAreaInsets.top
        )
    }
}

@MainActor
enum NotchGeometry {
    static func targetScreen() -> NSScreen? {
        NSScreen.screens.first(where: \.isBuiltInDisplay)
            ?? NSScreen.screens.first { $0.measuredNotchSize != .zero }
            ?? NSScreen.main
            ?? NSScreen.screens.first
    }

    static func layout(for screen: NSScreen?) -> NotchLayout {
        let screenFrame = screen?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let measured = screen?.measuredNotchSize ?? .zero
        let fallbackNotch = NSSize(width: 210, height: 32)
        let notch = measured == .zero ? fallbackNotch : measured

        let compactWidth = min(max(notch.width - 6, 182), 238)
        let compactHeight = min(max(notch.height + 2, 32), 38)
        let expandedWidth = min(max(notch.width + 220, 480), 540, screenFrame.width - 36)
        let expandedHeight = min(max(notch.height + 374, 408), screenFrame.height - 84)

        return NotchLayout(
            notchSize: notch,
            compactSize: NSSize(width: compactWidth, height: compactHeight),
            expandedSize: NSSize(width: expandedWidth, height: expandedHeight),
            compactTopOffset: 0,
            expandedTopOffset: 0
        )
    }

    static func centerMenuBarFrame(
        screenFrame: NSRect,
        visibleFrame: NSRect,
        menuBarHeight: CGFloat
    ) -> NSRect? {
        let reservedTopHeight = screenFrame.maxY - visibleFrame.maxY
        let activationHeight = min(menuBarHeight, reservedTopHeight)
        let menuBarWidth = screenFrame.width / 6
        guard menuBarWidth > 0, activationHeight > 0 else { return nil }

        return NSRect(
            x: screenFrame.midX - menuBarWidth / 2,
            y: screenFrame.maxY - activationHeight,
            width: menuBarWidth,
            height: activationHeight
        )
    }

    nonisolated static func physicalNotchFrame(
        screenFrame: NSRect,
        leftArea: NSRect,
        rightArea: NSRect,
        notchHeight: CGFloat
    ) -> NSRect? {
        let notchWidth = rightArea.minX - leftArea.maxX
        guard notchWidth > 0, notchHeight > 0, notchHeight <= screenFrame.height else { return nil }

        return NSRect(
            x: leftArea.maxX,
            y: screenFrame.maxY - notchHeight,
            width: notchWidth,
            height: notchHeight
        )
    }

    static func clickActivationSize(compactSize: NSSize, notchLimitSize: NSSize) -> NSSize {
        NSSize(
            width: max(min(compactSize.width, notchLimitSize.width), 0),
            height: max(min(compactSize.height, notchLimitSize.height), 0)
        )
    }
}
