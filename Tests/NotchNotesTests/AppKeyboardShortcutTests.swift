import AppKit
import XCTest
@testable import NotchNotes

final class AppKeyboardShortcutTests: XCTestCase {
    func testCommandOnlyShortcuts() {
        XCTAssertEqual(shortcut("n"), .newNote)
        XCTAssertEqual(shortcut("w"), .hideNotes)
        XCTAssertEqual(shortcut("q"), .quit)
        XCTAssertEqual(shortcut("z"), .undo)
        XCTAssertEqual(shortcut("x"), .cut)
        XCTAssertEqual(shortcut("c"), .copy)
        XCTAssertEqual(shortcut("v"), .paste)
        XCTAssertEqual(shortcut("a"), .selectAll)
        XCTAssertEqual(shortcut("f"), .showFind)
        XCTAssertEqual(shortcut("g"), .findNext)
    }

    func testShiftedShortcuts() {
        XCTAssertEqual(shortcut("Z", modifiers: [.command, .shift]), .redo)
        XCTAssertEqual(shortcut("G", modifiers: [.command, .shift]), .findPrevious)
    }

    func testUnsupportedModifiersDoNotTriggerShortcuts() {
        XCTAssertNil(shortcut("c", modifiers: [.command, .option]))
        XCTAssertNil(shortcut("v", modifiers: [.command, .control]))
        XCTAssertNil(shortcut("n", modifiers: [.command, .shift]))
        XCTAssertNil(shortcut("n", modifiers: []))
    }

    private func shortcut(
        _ key: String,
        modifiers: NSEvent.ModifierFlags = [.command]
    ) -> AppKeyboardShortcut? {
        AppKeyboardShortcut(
            charactersIgnoringModifiers: key,
            modifierFlags: modifiers
        )
    }
}
