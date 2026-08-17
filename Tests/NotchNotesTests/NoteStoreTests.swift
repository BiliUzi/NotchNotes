import Foundation
import XCTest
@testable import NotchNotes

@MainActor
final class NoteStoreTests: XCTestCase {
    func testPersistsNotesSelectionAndReadableTitles() throws {
        let environment = try makeEnvironment()
        defer { environment.cleanUp() }

        let store = NoteStore(
            defaults: environment.defaults,
            archiveURL: environment.archiveURL
        )
        store.updateText("# Project log\nFirst entry")
        store.updateSelection(
            for: store.activeTabID,
            range: NSRange(location: 4, length: 3)
        )
        XCTAssertEqual(store.title(for: store.activeTabID), "Project log")

        let firstTabID = store.activeTabID
        store.addTab()
        store.updateText("- [ ] Follow up")
        store.flush()

        let restored = NoteStore(
            defaults: environment.defaults,
            archiveURL: environment.archiveURL
        )
        XCTAssertEqual(restored.tabs.count, 2)
        XCTAssertEqual(restored.text, "- [ ] Follow up")
        XCTAssertEqual(restored.title(for: firstTabID), "Project log")
        XCTAssertEqual(
            restored.selectionRange(for: firstTabID),
            NSRange(location: 4, length: 3)
        )
    }

    func testDeletingActiveNoteSelectsRemainingNote() throws {
        let environment = try makeEnvironment()
        defer { environment.cleanUp() }

        let store = NoteStore(
            defaults: environment.defaults,
            archiveURL: environment.archiveURL
        )
        store.updateText("Keep this note")
        let originalID = store.activeTabID
        store.addTab()

        store.selectTab(originalID)
        store.removeTab(originalID)
        XCTAssertFalse(store.tabs.contains(where: { $0.id == originalID }))
        XCTAssertEqual(store.tabs.count, 1)
        XCTAssertEqual(store.activeTabID, store.tabs[0].id)
    }

    func testDeletingInactiveNoteKeepsCurrentNoteActive() throws {
        let environment = try makeEnvironment()
        defer { environment.cleanUp() }

        let store = NoteStore(
            defaults: environment.defaults,
            archiveURL: environment.archiveURL
        )
        let firstID = store.activeTabID
        store.addTab()
        let activeID = store.activeTabID

        store.removeTab(firstID)

        XCTAssertEqual(store.activeTabID, activeID)
        XCTAssertFalse(store.tabs.contains(where: { $0.id == firstID }))
    }

    func testArchiveRecoversNotesWhenDefaultsDataIsMissing() throws {
        let environment = try makeEnvironment()
        defer { environment.cleanUp() }

        let store = NoteStore(
            defaults: environment.defaults,
            archiveURL: environment.archiveURL
        )
        store.updateText("Recovery copy")
        store.flush()

        environment.defaults.removeObject(forKey: "notchNotes.tabs.v1")
        environment.defaults.removeObject(forKey: "notchNotes.archive.v2")
        environment.defaults.removeObject(forKey: "notchNotes.activeTabID")

        let recovered = NoteStore(
            defaults: environment.defaults,
            archiveURL: environment.archiveURL
        )
        XCTAssertEqual(recovered.text, "Recovery copy")
    }

    func testLoadsLegacyTabsWithCreatedAtMetadata() throws {
        struct LegacyNoteTab: Codable {
            let id: UUID
            let text: String
            let createdAt: Date
        }

        let environment = try makeEnvironment()
        defer { environment.cleanUp() }

        let legacyTab = LegacyNoteTab(
            id: UUID(),
            text: "Legacy note",
            createdAt: Date()
        )
        environment.defaults.set(
            try JSONEncoder().encode([legacyTab]),
            forKey: "notchNotes.tabs.v1"
        )

        let store = NoteStore(
            defaults: environment.defaults,
            archiveURL: environment.archiveURL
        )

        XCTAssertEqual(store.activeTabID, legacyTab.id)
        XCTAssertEqual(store.text, legacyTab.text)
        store.flush()
    }

    private func makeEnvironment() throws -> TestEnvironment {
        let suiteName = "NoteStoreTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("NotchNotesTests-\(UUID().uuidString)", isDirectory: true)
        return TestEnvironment(
            suiteName: suiteName,
            defaults: defaults,
            directory: directory,
            archiveURL: directory.appendingPathComponent("notes.json")
        )
    }
}

private struct TestEnvironment {
    let suiteName: String
    let defaults: UserDefaults
    let directory: URL
    let archiveURL: URL

    func cleanUp() {
        defaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: directory)
    }
}
