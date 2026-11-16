#if !STANDALONE_TESTS
import XCTest
@testable import LauncherCore
#else
import Foundation
#endif

final class LauncherPreferencesTests: XCTestCase {
    func testStartsWithNoSelectedApps() {
        XCTAssertTrue(LauncherPreferences().selectedPaths.isEmpty)
    }

    func testSelectionIsUniqueAndRemovalDoesNotAffectOthers() {
        var preferences = LauncherPreferences()
        preferences.setSelected("Arknights.app", selected: true)
        preferences.setSelected("BambuStudio.app", selected: true)
        preferences.setSelected("Arknights.app", selected: true)
        XCTAssertEqual(preferences.selectedPaths, ["Arknights.app", "BambuStudio.app"])
        preferences.setSelected("Arknights.app", selected: false)
        XCTAssertEqual(preferences.selectedPaths, ["BambuStudio.app"])
    }

    func testDragInBothDirectionsPreservesOtherApps() {
        var preferences = LauncherPreferences(selectedPaths: ["A", "B", "C", "D"])
        preferences.move("A", to: "C")
        XCTAssertEqual(preferences.selectedPaths, ["B", "C", "A", "D"])
        preferences.move("D", to: "B")
        XCTAssertEqual(preferences.selectedPaths, ["D", "B", "C", "A"])
        preferences.move("missing", to: "A")
        preferences.move("A", to: "A")
        XCTAssertEqual(preferences.selectedPaths, ["D", "B", "C", "A"])
    }

    func testAccessibleReorderClampsAtEdges() {
        var preferences = LauncherPreferences(selectedPaths: ["A", "B", "C"])
        preferences.move("A", by: -1)
        preferences.move("C", by: 1)
        XCTAssertEqual(preferences.selectedPaths, ["A", "B", "C"])
        preferences.move("B", by: -1)
        XCTAssertEqual(preferences.selectedPaths, ["B", "A", "C"])
    }

    func testPersistedOrderSelectionAndShortcutRoundTrip() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = PreferencesFile(url: directory.appendingPathComponent("settings.json"))
        XCTAssertTrue(try file.load().selectedPaths.isEmpty)
        let original = LauncherPreferences(selectedPaths: ["B", "A"], customPaths: ["/Games/A.app"], shortcut: nil)
        try file.save(original)
        XCTAssertEqual(try file.load(), original)
    }

    func testCorruptFileIsReportedInsteadOfSilentlyReset() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("not json".utf8).write(to: url)
        XCTAssertThrowsError(try PreferencesFile(url: url).load())
    }
}
